%% @copyright 2007-2008 Basho Technologies

%% @reference Ralph C. Merkle, A Digital Signature Based on a
%% Conventional Encryption Function, A Conference on the Theory and
%% Applications of Cryptographic Techniques on Advances in Cryptology,
%% p.369-378, August 16-20, 1987

% @author Justin Sheehy <justin@basho.com>

% @doc An implementation of Merkle Trees for anti-entropy.
%
% Intended use is for synchronizing two key/value stores with
% similar but potentially-divergent content.
%
% Typical usage is when a pair (or more) of nodes or systems have
% views of a set of key/value objects which can change independently.
% Whenever a new object is created or an existing one is modified
% (there is no difference from the merkle point of view) the node
% seeing the change performs an insert/2 to record the change.  At any
% time, one node can send a representation of its tree to another
% node.  The receiving node can diff/2 the trees to see which objects
% differ on the two systems.  From this information, a system knows
% exactly which objects to send or request in order to converge toward
% a common view of the world.  Of course, if the objects contain
% versioning information it will be much easier to resolve which
% node's view for any given object is newer.
%
% See the code of test_merkle/0 for trivial example usage.
%
% Application usage note: the 'crypto' OTP application must be started
% before any of this module's functions will work.
%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%
%% http://www.apache.org/licenses/LICENSE-2.0
%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.
-module(merkerl).
-author('justin@basho.com').
-vsn('$Id$').

-include("scalaris.hrl").

-export([insert/2,delete/2,build_tree/1,diff/2,test_merkle/0,allkeys/1, contains/2]).

% NOTE: userdata is the user-exposed key, 'key' is internal-only
-record(merk, {nodetype          :: inner | leaf,                     % atom: expected values are 'leaf' or 'inner'
               key=undefined     :: undefined | binary() | [any()],   % if nodetype=leaf, then this is binary/160
                                                                      % (keys are 160b binaries)
               userdata=undefined:: undefined | any(),                % (if user specified a non-binary key)
	       hashval,                                               % hash of value if leaf, of children if inner
	       offset=undefined  :: undefined | non_neg_integer(),    % if inner, then offset to reach here
	       children=undefined:: undefined | list({any(), any()})  % if nodetype=inner, then this is orddict
	       }).

% an internal-only form
-record(merkitem, {userdata=undefined, % for non-binary "keys"
                   hkey,               % SHA-1 of userdata
                   hval                % SHA-1 of value (user-supplied)
                  }).

% @type treeleaf() = term().
% Not externally useful, this is one of two record types making up tree().

% @type treeinner() = term().
% Not externally useful, this is one of two record types making up tree().

-type(tree() :: #merk{} | undefined).
% @type tree() = treeleaf() | treeinner() | undefined.
% The tree() type here is used as the internal representation of
% a Merkle tree.  It can be used locally with insert/2 or pickled
% via term_to_binary and inverse for use remotely in diff/2.

-type(userdata() :: any()).
% @type userdata().
% This is the key, or "name" for an object tracked by a Merkle tree.
% It should remain constant through changes to the object it references.

-type(hash() :: any()).
% @type hash().
% This is a unique value representing the content of an object tracked
% by a Merkle tree.
% It should change if the object it references changes in value.

% @spec build_tree([{userdata(), hash()}]) -> tree()
% @doc Build a Merkle tree from a list of pairs representing objects'
%      names (keys) and hashes of their values.
-spec(build_tree/1 :: (list({userdata(), hash()})) -> #merk{}).
build_tree([{K,H}]) ->
    insert({K,H},undefined);
build_tree([{K,H}|KHL]) ->
    insert({K,H},build_tree(KHL)).

% @spec delete(userdata(), tree()) -> tree()
% @doc Remove the specified item from a tree.
-spec(delete(userdata(), tree()) -> tree()).
delete(Key, Tree) when is_record(Tree, merk) ->
    mi_delete({0, #merkitem{userdata=Key,hkey=sha(Key),hval=undefined}}, Tree).
mi_delete({Offset, MI}, Tree) ->
    HKey = MI#merkitem.hkey,
    case Tree#merk.nodetype of
	leaf ->
	    case Tree#merk.key of
		HKey ->
		    undefined;
		_ ->
		    Tree
	    end;
	inner ->
            Kids = Tree#merk.children,
            OKey = offset_key(Offset,HKey),
            NewKids = case orddict:is_key(OKey,Kids) of
                          false ->
                              Kids;
                          true ->
                              SubTree = orddict:fetch(OKey,Kids),
                              orddict:store(OKey,
                                      mi_delete({Offset+8,MI},SubTree),Kids)
                      end,
            mkinner(Offset,NewKids)
    end.
    
% @spec insert(X :: {userdata(), hash()},T :: tree()) -> tree()
% @doc Insert the data for a new or changed object X into T.
%
% userdata is any term; internally the key used is produced by
% sha1(term_to_binary(userdata)).  When the value referenced by
% a userdata key changes, then the userdata is expected not to change.
%
% the hash is expected to be a value that will only compare equal
% (==) to another userdata key's hash if the values references by
% those two keys is also equal.
%
% This is used much like a typical tree-insert function.
% To create a new tree, this can be called with T set to the atom 'undefined'.
-spec(insert/2 :: ({userdata(), hash()}, tree()) -> #merk{}).
insert({Userdata, Hashval}, T) ->
    mi_insert(#merkitem{userdata=Userdata,hkey=sha(Userdata),hval=Hashval}, T).
mi_insert(MI,T) when is_record(MI, merkitem) ->
    mi_insert({0,MI},T);
mi_insert({_Offset,MI},undefined) ->
    mkleaf(MI);
mi_insert({160,MI},_Tree) ->
    % we're all the way deep!  replace.
    mkleaf(MI);
mi_insert({Offset,MI},Tree) ->
    Key = MI#merkitem.hkey,
    case Tree#merk.nodetype of
	leaf ->
	    case Tree#merk.key of
		Key -> % replacing!
		    mkleaf(MI);
		_ -> % turning a leaf into an inner
		    K0 = orddict:new(),
		    K1 = orddict:store(offset_key(Offset,Key),
				       mkleaf(MI),K0),
		    TKey = Tree#merk.key,
		    Kids = orddict:store(offset_key(Offset,TKey),Tree,K1),
		    mkinner(Offset,Kids)
	    end;
	inner ->
	    mi_insert1({Offset,MI},Tree)
    end.
mi_insert1({Offset,MI},Tree) ->
    Kids = Tree#merk.children,
    OKey = offset_key(Offset,MI#merkitem.hkey),
    NewKids = case orddict:is_key(OKey,Kids) of
		  false ->
		      orddict:store(OKey,mkleaf(MI),Kids);
		  true ->
		      SubTree = orddict:fetch(OKey,Kids),
		      orddict:store(OKey,
				   mi_insert({Offset+8,MI},SubTree),Kids)
	      end,
    mkinner(Offset,NewKids).

mkleaf(MI) ->
    #merk{nodetype=leaf,
          key=MI#merkitem.hkey,
          userdata=MI#merkitem.userdata,
          hashval=MI#merkitem.hval}.

mkinner(Offset,Kids) ->
    #merk{nodetype=inner,hashval=sha(Kids),offset=Offset,
          children=[{K,V} || {K,V} <- Kids, V =/= undefined]}.

offset_key(Offset,Key) ->
    % offset is a 8b-divisible integer from 0 to 152, inclusive
    % Key is a 160b binary
    <<_L:Offset/integer,RightKey/binary>> = Key,
    <<OKey:8/integer,_R/binary>> = RightKey,
    OKey.

% @spec diff(tree(), tree()) -> [userdata()]
% @doc Find the keys of objects which differ between the two trees.
%
% For this purpose, "differ" means that an object either exists in
% only one of the two trees or it exists in both but with different
% hash() values.
%
% No information about the differing objects is provided except the keys.
% (Objects with vector-clock versioning are helpful here)
-spec(diff/2 :: (tree(), tree()) -> list(userdata())).
diff(undefined, TreeB) -> allkeys(TreeB);
diff(TreeA, undefined) -> allkeys(TreeA);
diff(TreeA,TreeB) when is_record(TreeA,merk),is_record(TreeB,merk) ->
    % return the list of 'userdata' fields from inner nodes that differ
    lists:usort(diff1(TreeA,TreeB)).
diff1(TreeA,TreeB) ->
    % precondition: TreeA and TreeB are both merks at same offset
    case TreeA#merk.hashval =:= TreeB#merk.hashval of
 	true ->
 	    [];
 	false ->
	    diff2(TreeA,TreeB)
    end.
diff2(TreeA,TreeB) ->
    % precondition: TreeA and TreeB are both merks at same offset
    % precondition: TreeA and TreeB have different hashval
    case TreeA#merk.nodetype =:= TreeB#merk.nodetype andalso
	TreeA#merk.nodetype =:= leaf of
	true ->
	    [TreeA#merk.userdata,TreeB#merk.userdata];
	false ->
	    diff3(TreeA,TreeB)
    end.
diff3(TreeA,TreeB) ->
    % precondition: TreeA and TreeB are both merks at same offset
    % precondition: TreeA and TreeB have different hashval
    % precondition: at least one of TreeA and TreeB is not a leaf
    case TreeA#merk.nodetype =:= leaf of
	true ->
	    allbutmaybe(TreeB,TreeA);
	false ->
	    case TreeB#merk.nodetype =:= leaf of
		true ->
		    allbutmaybe(TreeA,TreeB);
		false ->
		    diff4(TreeA,TreeB)
	    end
    end.
diff4(TreeA,TreeB) ->
    % precondition: TreeA and TreeB are both merks at same offset
    % precondition: TreeA and TreeB have different hashval
    % precondition: TreeA and TreeB are both inner nodes
    diff4a(TreeA#merk.children,TreeB#merk.children,0,[]).
diff4a(KidsA,KidsB,Idx,Acc) ->
    % this is the ugly bit.
    case Idx > 255 of
	true ->
	    Acc;
	false ->
	    case KidsA of
		[] ->
		    lists:append(Acc,lists:flatten([allkeys(X) ||
                                                       {_Okey, X} <- KidsB]));
		_ ->
		    case KidsB of
			[] ->
			    lists:append(Acc,lists:flatten(
					       [allkeys(X) ||
                                                   {_Okey, X} <- KidsA]));
			_ ->
			    diff4b(KidsA,KidsB,Idx,Acc)
		    end
	    end
    end.
diff4b(KidsA,KidsB,Idx,Acc) ->
    % precondition: neither KidsA nor KidsB is empty
    [{OkeyA,NodeA}|RestA] = KidsA,
    [{OkeyB,NodeB}|RestB] = KidsB,
    case OkeyA =:= Idx of
	true ->
	    case OkeyB =:= Idx of
		true ->
		    diff4a(RestA,RestB,Idx+1,
			   lists:append(Acc,diff1(
					      NodeA,NodeB)));
		false ->
		    diff4a(RestA,KidsB,Idx+1,
			   lists:append(Acc,allkeys(
					      NodeA)))
	    end;
	false ->
	    case OkeyB =:= Idx of
		true ->
		    diff4a(KidsA,RestB,Idx+1,
			   lists:append(Acc,allkeys(
					      NodeB)));
		false ->
		    diff4a(KidsA,KidsB,Idx+1,Acc)
	    end
    end.

% @spec allkeys(tree()) -> [userdata()]
% @doc Produce all keys referenced in a Merkle tree.
-spec(allkeys/1 :: (tree()) -> list(userdata())).
allkeys(undefined) -> [];
allkeys(Tree) when is_record(Tree, merk) ->
    case Tree#merk.nodetype of
	leaf ->
	    [Tree#merk.userdata];
	_ ->
	    lists:flatten([allkeys(Kid) || Kid <- getkids(Tree)])
    end.
	    
allbutmaybe(Tree,Leaf) when is_record(Tree, merk),is_record(Leaf,merk) ->
    % return all keys in Tree, maybe the one for Leaf
    % (depending on whether it is present&identical in Tree)
    case contains_node(Tree,Leaf) of
	true ->
	    lists:delete(Leaf#merk.userdata,allkeys(Tree));
	false ->
	    lists:append([Leaf#merk.userdata],allkeys(Tree))
    end.

contains_node(Tree,Node) ->
    case Tree#merk.nodetype of
	leaf ->
	    Tree#merk.hashval =:= Node#merk.hashval;
	_ ->
	    lists:any(fun(T) -> contains_node(T,Node) end, getkids(Tree))
    end.
	    
getkids(Tree) ->
    [V || {_K,V} <- orddict:to_list(Tree#merk.children)].

sha(X) ->
    crypto:sha(term_to_binary(X)).

assert(X, X) -> true.

% @spec contains(tree(), userdata()) -> boolean()
% @doc Checks whether the specified item is in the tree.
-spec(contains/2 :: (tree(), userdata()) -> boolean()).
contains(undefined, _Key)  ->
    false;
contains(Tree, Key) when is_record(Tree, merk) ->
    mi_contains({0, #merkitem{userdata=Key,hkey=sha(Key),hval=undefined}}, Tree).
mi_contains({Offset, MI}, Tree) ->
    HKey = MI#merkitem.hkey,
    case Tree#merk.nodetype of
	leaf ->
	    Tree#merk.key =:= HKey;
	inner ->
            Kids = Tree#merk.children,
            OKey = offset_key(Offset,HKey),
            case orddict:is_key(OKey,Kids) of
		false ->
		    false;
		true ->
		    SubTree = orddict:fetch(OKey,Kids),
		    mi_contains({Offset+8,MI},SubTree)
	    end
    end.

% @spec test_merkle() -> boolean()
% @doc A test function and example code.
%
% This should be changed into a proper unit test suite.
-spec(test_merkle/0 :: () -> true).
test_merkle() ->
    A = [{one,"one data"},{two,"two data"},{three,"three data"},
	 {four,"four data"},{five,"five data"}],
    B = [{one,"one data"},{two,"other two"},{three,"three data"},
	 {four,"other four"},{five,"five data"}],
    A2 = build_tree(A),
    B2 = build_tree(B),
    assert(diff(A2,B2), lists:usort([two, four])),
    C = [{one,"one data"}],
    C2 = build_tree(C),
    assert(diff(A2,C2), lists:usort([two, three, four, five])),
    D = insert({four, sha("changed!")}, A2),
    assert(diff(A2,D), [four]),
    E = insert({five, sha("changed more!")}, D),
    assert(diff(D,E), [five]),
    assert(diff(A2,E), lists:usort([four, five])),
    F = delete(five,D),
    G = delete(five,E),
    assert(diff(F,G), []),
    H = delete(two,A2),
    assert(diff(A2,H), [two]),
    assert(diff(C2,undefined), [one]),
    % contains tests
    assert(contains(A2, one), true),
    assert(contains(A2, two), true),
    assert(contains(A2, three), true),
    assert(contains(A2, four), true),
    assert(contains(A2, five), true),
    assert(contains(A2, six), false),
    assert(contains(A2, seven), false),
    assert(contains(A2, eight), false).
    
