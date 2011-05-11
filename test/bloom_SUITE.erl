%  @copyright 2010-2011 Zuse Institute Berlin
%  @end
%
%   Licensed under the Apache License, Version 2.0 (the "License");
%   you may not use this file except in compliance with the License.
%   You may obtain a copy of the License at
%
%       http://www.apache.org/licenses/LICENSE-2.0
%
%   Unless required by applicable law or agreed to in writing, software
%   distributed under the License is distributed on an "AS IS" BASIS,
%   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%   See the License for the specific language governing permissions and
%   limitations under the License.
%%%-------------------------------------------------------------------
%%% File    bloom_SUITE.erl
%%% @author Maik Lange <MLange@informatik.hu-berlin.de>
%%% @doc    Tests for the bloom filter module.
%%% @end
%%% Created : 06/04/2011 by Maik Lange <MLange@informatik.hu-berlin.de>
%%%-------------------------------------------------------------------
%% @version $Id: gossip_SUITE.erl 1629 2011-03-30 09:28:04Z kruber@zib.de $

-module(bloom_SUITE).

-compile(export_all).

-include("scalaris.hrl").
-include("unittest.hrl").

-define(BLOOM, bloom).
-define(HFS, hfs_lhsp_md5).

-define(Fpr_Test_NumTests, 30).
-define(Fpr_Test_DestFPR, 0.001).
-define(Fpr_Test_ElementNum, 1000).

all() -> [
		  add,
		  addRange,
          join,
          equals,
          fpr_test_parallel
		 ].

add(_) -> 
	BF = newBloom(10, 0.1),
	B1 = ?BLOOM:add(BF, "10"),
	B2 = ?BLOOM:add(B1, 10),
	B3 = ?BLOOM:add(B2, 10.3),
    ?equals(?BLOOM:is_element(B3, "10"), true),
    ?equals(?BLOOM:is_element(B3, "100"), false),
    ?equals(?BLOOM:is_element(B3, 10.3), true).

addRange(_) ->	
	BF = newBloom(10, 0.1),
	Elements = lists:seq(1,10,1),
	BF1 = ?BLOOM:addRange(BF, Elements),
	Results = [ ?BLOOM:is_element(BF1, Item) || Item <- Elements],
	io:format("Elements: ~p~n", [Elements]),
	io:format("Results: ~p~n", [Results]),
	?equals(lists:member(false, Results), false),
    ?equals(?BLOOM:is_element(BF1, "Not"), false),
    ?equals(?BLOOM:is_element(BF1, 2), true).

join(_) ->
    BF1 = for_to_ex(1, 10, fun(I) -> I end, fun(I, B) -> ?BLOOM:add(B, I) end, newBloom(30, 0.1)),
    BF2 = for_to_ex(11, 20, fun(I) -> I end, fun(I, B) -> ?BLOOM:add(B, I) end, newBloom(30, 0.1)),
    BF3 = ?BLOOM:join(BF1, BF2),
    NumFound = for_to_ex(1, 20, 
                         fun(I) -> case ?BLOOM:is_element(BF3, I) of
                                       true -> 1;
                                       false -> 0
                                   end
                         end,
                         fun(X,Y) -> X+Y end, 0),
    io:format("join NumFound=~B~n", [NumFound]),
    ?assert(NumFound > 10 andalso NumFound =< 20),
    ok.

equals(_) ->
    BF1 = for_to_ex(1, 10, fun(I) -> I end, fun(I, B) -> ?BLOOM:add(B, I) end, newBloom(30, 0.1)),
    BF2 = for_to_ex(1, 10, fun(I) -> I end, fun(I, B) -> ?BLOOM:add(B, I) end, newBloom(30, 0.1)),    
    ?equals(?BLOOM:equals(BF1, BF2), true),
    ok.

%% @doc ?Fpr_Test_NumTests-fold parallel run of measure_fp
fpr_test_parallel(_) ->
    FalsePositives = util:p_repeatAndAccumulate(
                       fun measure_fp/2, 
                       [?Fpr_Test_DestFPR, ?Fpr_Test_ElementNum], 
                       ?Fpr_Test_NumTests, 
                       fun(X, Y) -> X + Y end, 
                       0),
    AvgFpr = FalsePositives / ?Fpr_Test_NumTests,
    ?BLOOM:print(newBloom(?Fpr_Test_ElementNum, ?Fpr_Test_DestFPR)),
    io:format("~nDestFpr: ~f~nMeasured Fpr: ~f~n", [?Fpr_Test_DestFPR, AvgFpr]),
    ?assert(?Fpr_Test_DestFPR >= AvgFpr orelse ?Fpr_Test_DestFPR*1.3 >= AvgFpr),
    ok.   

%% @doc measures false positives by adding 1..MaxElements into a new BF
%%      and checking number of found items which are not in the BF
measure_fp(DestFpr, MaxElements) ->
	BF = newBloom(MaxElements, DestFpr),
    BF1 = for_to_ex(1, MaxElements, fun(I) -> I end, fun(I, B) -> ?BLOOM:add(B, I) end, BF),
	NumNotIn = trunc(10 / DestFpr),
    NumFound = for_to_ex(MaxElements + 1, 
                         MaxElements + 1 + NumNotIn, 
                         fun(I) -> case ?BLOOM:is_element(BF1, I) of
                                       true -> 1;
                                       false -> 0
                                   end
                         end,
                         fun(X,Y) -> X+Y end,
                         0),       
	NumFound / NumNotIn.

newBloom(ElementNum, Fpr) ->
	HFCount = ?BLOOM:calc_HF_numEx(ElementNum, Fpr),
	Hfs = ?HFS:new(HFCount),
	?BLOOM:new(ElementNum, Fpr, Hfs).


%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% UTILS
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

for_to_ex(I, N, Fun, AccuFun, Accu) ->
    NewAccu = AccuFun(Fun(I), Accu),
    if 
        I < N ->
            for_to_ex(I + 1, N, Fun, AccuFun, NewAccu);
        I =:= N ->
            NewAccu;
        I > N ->
            failed
    end.