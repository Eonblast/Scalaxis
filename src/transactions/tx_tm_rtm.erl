% @copyright 2009-2011 Zuse Institute Berlin,
%            2009 onScale solutions GmbH

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

%% @author Florian Schintke <schintke@onscale.de>
%% @doc Part of a generic implementation of transactions using Paxos Commit -
%%      the roles of the (replicated) transaction manager TM and RTM.
%% @end
%% @version $Id$
-module(tx_tm_rtm).
-author('schintke@zib.de').
-vsn('$Id$').

%%-define(TRACE_RTM_MGMT(X,Y), io:format(X,Y)).
%%-define(TRACE_RTM_MGMT(X,Y), ct:pal(X,Y)).
-define(TRACE_RTM_MGMT(X,Y), ok).
%-define(TRACE(X,Y), ct:pal(X,Y)).
-define(TRACE(_X,_Y), ok).
-behaviour(gen_component).
-include("scalaris.hrl").

%% public interface for transaction validation using Paxos-Commit.
-export([commit/4]).
-export([msg_commit_reply/3]).
-export([rm_send_update/4]).

%% functions for gen_component module, supervisor callbacks and config
-export([start_link/2]).
-export([on/2, init/1]).
-export([on_init/2]).
-export([get_my/2]).
-export([check_config/0]).

-ifdef(with_export_type_support).
-export_type([rtms/0]).
-endif.

%% messages a client has to expect when using this module
-spec msg_commit_reply(comm:mypid(), any(), any()) -> ok.
msg_commit_reply(Client, ClientsID, Result) ->
    comm:send(Client, {tx_tm_rtm_commit_reply, ClientsID, Result}).

%% public interface for transaction validation using Paxos-Commit.
%% ClientsID may be nil, its not used by tx_tm. It will be repeated in
%% replies to allow to map replies to the right requests in the
%% client.
-spec commit(comm:erl_local_pid(), comm:mypid(), any(), tx_tlog:tlog()) -> ok.
commit(TM, Client, ClientsID, TLog) ->
    Msg = {tx_tm_rtm_commit, Client, ClientsID, TLog},
    comm:send_local(TM, Msg).

%% @doc Notifies the tx_tm_rtm of a changed node ID.
-spec rm_send_update(Subscriber::pid(), Tag::?MODULE,
                     OldNeighbors::nodelist:neighborhood(),
                     NewNeighbors::nodelist:neighborhood()) -> ok.
rm_send_update(Pid, ?MODULE, OldNeighbors, NewNeighbors) ->
    OldId = node:id(nodelist:node(OldNeighbors)),
    NewId = node:id(nodelist:node(NewNeighbors)),
    case OldId =/= NewId of
        true  -> comm:send_local(Pid, {new_node_id, NewId});
        false -> ok
    end.

%% be startable via supervisor, use gen_component
-spec start_link(pid_groups:groupname(), any()) -> {ok, pid()}.
start_link(DHTNodeGroup, Role) ->
    gen_component:start_link(?MODULE,
                             [],
                             [{pid_groups_join_as, DHTNodeGroup, Role}]).

-type rtms() :: [{?RT:key(), comm:mypid() | unknown,
                  non_neg_integer(), comm:mypid()}].

-type state() ::
    {RTMs           :: rtms(),
     TableName      :: pdb:tableid(),
     Role           :: pid_groups:pidname(),
     LocalAcceptor  :: pid(),
     GLocalLearner   :: comm:mypid()}.

-type state_uninit() ::
    {RTMs           :: rtms(),
     TableName      :: pdb:tableid(),
     Role           :: pid_groups:pidname(),
     LocalAcceptor  :: pid(),
     GLocalLearner  :: comm:mypid(),
     QueuedMessages :: msg_queue:msg_queue()}.

%% initialize: return initial state.
-spec init([]) -> state() | {'$gen_component', [{on_handler, on_init},...],
                             state_uninit()}.
init([]) ->
    Role = pid_groups:my_pidname(),
    ?TRACE("tx_tm_rtm:init for instance: ~p ~p~n",
           [pid_groups:my_groupname(), Role]),
    %% For easier debugging, use a named table (generates an atom)
    TableName = list_to_atom(pid_groups:my_groupname() ++ "_tx_tm_rtm_"
                             ++ atom_to_list(Role)),
    pdb:new(TableName, [set, protected, named_table]),
    %% use random table name provided by ets to *not* generate an atom
    %% TableName = pdb:new(?MODULE, [set, private]),
    LAcceptor = get_my(Role, acceptor),
    GLLearner = comm:make_global(get_my(Role, learner)),
    %% start getting rtms and maintain them.
    case Role of
        tx_tm ->
            comm:send_local(pid_groups:get_my(dht_node),
                            {get_node_details, comm:this(), [node]}),
            State = {_RTMs = [], TableName, Role, LAcceptor, GLLearner, msg_queue:new()},
            %% subscribe to id changes
            rm_loop:subscribe(self(), ?MODULE,
                              fun rm_loop:subscribe_dneighbor_change_filter/2,
                              fun ?MODULE:rm_send_update/4, inf),
            gen_component:change_handler(State, on_init);
        _ -> {_RTMs = [], TableName, Role, LAcceptor, GLLearner}
    end.

-spec on(comm:message(), state()) -> state().
%% a paxos consensus is decided (msg generated by learner.erl)
on({learner_decide, ItemId, _PaxosID, Value} = Msg, State) ->
    ?TRACE("tx_tm_rtm:on(~p)~n", [Msg]),
    {ErrItem, ItemState} = my_get_item_entry(ItemId, State),
    _ = case ok =/= ErrItem of
        true -> %% new / uninitialized
            %% hold back and handle when corresponding tx_state is
            %% created in init_RTM
            TmpItemState = tx_item_state:hold_back(Msg, ItemState),
            NewItemState = tx_item_state:set_status(TmpItemState, uninitialized),
            msg_delay:send_local((config:read(tx_timeout) * 3) div 1000, self(),
                                 {tx_tm_rtm_delete_itemid, ItemId}),
            my_set_entry(NewItemState, State);
        false -> %% ok
            TxId = tx_item_state:get_txid(ItemState),
            {ok, OldTxState} = my_get_tx_entry(TxId, State),
            TxState = tx_state:inc_numpaxdecided(OldTxState),
            TmpItemState =
                case Value of
                    prepared -> tx_item_state:inc_numprepared(ItemState);
                    abort ->    tx_item_state:inc_numabort(ItemState)
                end,
            {NewItemState, NewTxState} =
                case tx_item_state:newly_decided(TmpItemState) of
                    false -> {TmpItemState, TxState};
                    Decision -> %% prepared / abort
                        DecidedItemState =
                            tx_item_state:set_decided(TmpItemState, Decision),
                        %% record in tx_state
                        TmpTxState =
                            case Decision of
                                prepared -> tx_state:inc_numprepared(TxState);
                                abort    -> tx_state:inc_numabort(TxState)
                            end,
                        Tmp2TxState =
                            case tx_state:newly_decided(TmpTxState) of
                                undecided -> TmpTxState;
                                false -> TmpTxState;
                                Result -> %% commit or abort
                                    T1TxState = my_inform_tps(TmpTxState, State, Result),
                                    %% to inform, we do not need to know the new state
                                    my_inform_client(TxId, State, Result),
                                    my_inform_rtms(TxId, State, Result),
                                    %%%my_trigger_delete_if_done(T1TxState),
                                    tx_state:set_decided(T1TxState, Result)
                            end,
                        {DecidedItemState, Tmp2TxState}
                end,
            _ = my_set_entry(NewTxState, State),
            my_trigger_delete_if_done(NewTxState),
            my_set_entry(NewItemState, State)
    end,
    State;

on({tx_tm_rtm_commit, Client, ClientsID, TransLog},
   {RTMs, _TableName, _Role, _LAcceptor, GLLearner} = State) ->
    ?TRACE("tx_tm_rtm:on({commit, ...}) for TLog ~p as ~p~n", [TransLog, _Role]),
    Maj = config:read(quorum_factor),
    NewTid = {tx_id, util:get_global_uid()},
    NewTxItemIds = [ {tx_item_id, util:get_global_uid()} || _ <- TransLog ],
    TLogTxItemIds = lists:zip(TransLog, NewTxItemIds),
    TmpTxState = tx_state:new(NewTid, Client, ClientsID, RTMs,
                              TLogTxItemIds, [GLLearner]),
    TxState = tx_state:set_status(TmpTxState, ok),
    _ = my_set_entry(TxState, State),

    ItemStates =
        [ begin
              TItemState = tx_item_state:new(ItemId, NewTid, TLogEntry),
              ItemState = tx_item_state:set_status(TItemState, ok),
              _ = my_set_entry(ItemState, State),
              %% initialize local learner
              _ = [ learner:start_paxosid(GLLearner, element(1, X),
                                          Maj, comm:this(), ItemId)
                    || X <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ],
              ItemState
          end || {TLogEntry, ItemId} <- TLogTxItemIds ],

    my_start_fds_for_tid(NewTid, TxState),
    my_init_RTMs(TxState, ItemStates),
    my_init_TPs(TxState, ItemStates),
    State;

%% this tx is finished and enough TPs were informed, delete the state
on({tx_tm_rtm_delete, TxId, Decision} = Msg,
   {_RTMs, TableName, Role, LAcceptor, GLLearner} = State) ->
    ?TRACE("tx_tm_rtm:on({delete, ~p, ~p}) in ~p ~n", [TxId, Decision, Role]),
    %% TODO: use ok as error code?!
    %% {ok, TxState} = my_get_tx_entry(TxId, State),
    {ErrCode, TxState} = my_get_tx_entry(TxId, State),
    %% inform RTMs on delete
    case {ErrCode, Role} of
        {ok, tx_tm} ->
            RTMs = tx_state:get_rtms(TxState),
            _ = [ comm:send(get_rtmpid(RTM), Msg) || RTM <- RTMs ],
            %% inform used learner to delete paxosids.
            AllPaxIds =
                [ begin
                      {ok, ItemState} = my_get_item_entry(ItemId, State),
                      [ PaxId || {PaxId, _RTLog, _TP}
                        <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ]
                  end || {_TLogEntry, ItemId} <- tx_state:get_tlog_txitemids(TxState) ],
            %% We could delete immediately, but we still miss the
            %% minority of learner_decides, which would re-create the
            %% id in the learner, which then would have to be deleted
            %% separately, so we give the minority a second to arrive
            %% and then send the delete request.
            %% learner:stop_paxosids(GLLearner, lists:flatten(AllPaxIds)),
            msg_delay:send_local(1, comm:make_local(GLLearner),
                                 {learner_deleteids, lists:flatten(AllPaxIds)}),
            DeleteIt = true;
        {ok, _} ->
            %% the test my_trigger_delete was passed, at least by the TM
            %% RTMs only wait for all tp register messages, to not miss them
            %% record, that every TP was informed and all paxids decided
            TmpTxState = tx_state:set_numinformed(
                           TxState, tx_state:get_numids(TxState) *
                               config:read(replication_factor)),
            Tmp2TxState = tx_state:set_numpaxdecided(
                           TmpTxState, tx_state:get_numids(TxState) *
                                config:read(replication_factor)),
            Tmp3TxState = tx_state:set_decided(Tmp2TxState, Decision),
            _ = my_set_entry(Tmp3TxState, State),
            DeleteIt = tx_state:all_tps_registered(TxState),
            %% inform used acceptors to delete paxosids.
            AllPaxIds =
                [ begin
                  {ok, ItemState} = my_get_item_entry(ItemId, State),
                  [ PaxId || {PaxId, _RTlog, _TP}
                    <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ]
              end || {_TLogEntry, ItemId} <- tx_state:get_tlog_txitemids(TxState) ],
%%            msg_delay:send_local((config:read(tx_timeout) * 2) div 1000, LAcceptor,
%%                                 {acceptor_deleteids, lists:flatten(AllPaxIds)});
            comm:send_local(LAcceptor,
                               {acceptor_deleteids, lists:flatten(AllPaxIds)});
         {new, _} ->
            %% already deleted
            DeleteIt = false;
        {uninitialized, _} ->
            DeleteIt = false %% will be deleted when msg_delay triggers it
    end,
    case DeleteIt of
        false ->
            %% @TODO if we are a rtm, we still wait for register TPs
            %% trigger same delete later on, as we do not get a new
            %% request to delete from the tm
            ok;
        true ->
            %% unsubscribe RTMs from FD
            case Role of
                tx_tm -> my_stop_fds_for_tid(TxId, TxState);
                _ -> ok
            end,
            %% delete locally
            _ = [ pdb:delete(ItemId, TableName)
              || {_, ItemId} <- tx_state:get_tlog_txitemids(TxState)],
            pdb:delete(TxId, TableName)
            %% @TODO failure cases are not handled yet. If some
            %% participants do not respond, the state is not deleted.
            %% In the future, we will handle this using msg_delay for
            %% outstanding txids to trigger a delete of the items.
    end,
    State;

%% generated by on(register_TP) via msg_delay to not increase memory
%% footprint
on({tx_tm_rtm_delete_txid, TxId},
   {_RTMs, TableName, _Role, _LAcceptor, _GLLearner} = State) ->
    ?TRACE("tx_tm_rtm:on({delete_txid, ...}) ~n", []),
    %% Debug diagnostics and output:
    %%     {Status, Entry} = my_get_tx_entry(TxId, State),
    %%     case Status of
    %%         new -> ok; %% already deleted
    %%         uninitialized ->
    %%             %% @TODO inform delayed tps that they missed something?
    %%             %% See info in hold back queue.
    %%             io:format("Deleting an txid with hold back messages.~n~p~n",
    %%                       [tx_state:get_hold_back(Entry)]);
    %%         ok ->
    %%             io:format("Oops, this should have been cleaned normally.~n")
    %%     end,
    pdb:delete(TxId, TableName),
    State;

%% generated by on(learner_decide) via msg_delay to not increase memory
%% footprint
on({tx_tm_rtm_delete_itemid, TxItemId},
   {_RTMs, TableName, _Role, _LAcceptor, _GLLearner} = State) ->
    ?TRACE("tx_tm_rtm:on({delete_itemid, ...}) ~n", []),
    %% Debug diagnostics and output:
    %% {Status, Entry} = my_get_item_entry(TxItemId, State),
    %% case Status of
    %%     new -> ok; %% already deleted
    %%     uninitialized ->
    %% %%             %% @TODO inform delayed learners that they missed something?
    %%             %% See info in hold back queue.
    %%         io:format("Deleting an item with hold back massages.~n~p~n",
    %%                   [tx_item_state:get_hold_back(Entry)]);
    %%     ok ->
    %%         io:format("Oops, this should have been cleaned normally.~n")
    %% end,
    pdb:delete(TxItemId, TableName),
    State;

%% sent by my_init_RTMs
on({tx_tm_rtm_init_RTM, TxState, ItemStates, InRole} = _Msg,
   {_RTMs, _TableName, _Role, LAcceptor, _GLLearner} = State) ->
   ?TRACE("tx_tm_rtm:on({init_RTM, ...}) ~n", []),

    %% lookup transaction id locally and merge with given TxState
    Tid = tx_state:get_tid(TxState),
    {LocalTxStatus, LocalTxEntry} = my_get_tx_entry(Tid, State),
    TmpEntry = case LocalTxStatus of
                   new -> TxState; %% nothing known locally
                   uninitialized ->
                       %% take over hold back from existing entry
                       %%io:format("initRTM takes over hold back queue for id ~p in ~p~n", [Tid, Role]),
                       HoldBackQ = tx_state:get_hold_back(LocalTxEntry),
                       tx_state:set_hold_back(TxState, HoldBackQ);
                   ok -> log:log(error, "Duplicate init_RTM", [])
               end,
    NewEntry = tx_state:set_status(TmpEntry, ok),
    _ = my_set_entry(NewEntry, State),

    %% lookup items locally and merge with given ItemStates
    NewItemStates =
        [ begin
              EntryId = tx_item_state:get_itemid(Entry),
              {LocalItemStatus, LocalItem} = my_get_item_entry(EntryId, State),
              TmpItem = case LocalItemStatus of
                            new -> Entry; %% nothing known locally
                            uninitialized ->
                                %% take over hold back from existing entry
                                IHoldBQ = tx_item_state:get_hold_back(LocalItem),
                                tx_item_state:set_hold_back(Entry, IHoldBQ);
                            ok -> log:log(error, "Duplicate init_RTM for an item", [])
                        end,
              NewItem = tx_item_state:set_status(TmpItem, ok),
              _ = my_set_entry(NewItem, State),
              NewItem
          end || Entry <- ItemStates],
%%    io:format("New Item States: ~p~n", [NewItemStates]),

    %% initiate local paxos acceptors (with received paxos_ids)
    Learners = tx_state:get_learners(TxState),
    _ = [ [ acceptor:start_paxosid_local(LAcceptor, PaxId, Learners)
        || {PaxId, _RTlog, _TP}
               <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ]
      || ItemState <- NewItemStates ],

    %% process hold back messages for tx_state
    %% @TODO better use a foldr
    %% io:format("Starting hold back queue processing~n"),
    _ = [ on(OldMsg, State) || OldMsg <- lists:reverse(tx_state:get_hold_back(NewEntry)) ],
    %% process hold back messages for tx_items
    _ = [ [ on(OldMsg, State)
        || OldMsg <- lists:reverse(tx_item_state:get_hold_back(Item)) ]
      || Item <- NewItemStates],
    %% io:format("Stopping hold back queue processing~n"),

    %% set timeout and remember timerid to cancel, if finished earlier?
    msg_delay:send_local(1 + InRole, self(), {tx_tm_rtm_propose_yourself, Tid}),
    %% after timeout take over and initiate new paxos round as proposer
    %% done in on({tx_tm_rtm_propose_yourself...}) handler
    State;

% received by RTMs
on({register_TP, {Tid, ItemId, PaxosID, TP}} = Msg,
   {_RTMs, _TableName, Role, _LAcceptor, _GLLearner} = State) ->
    %% TODO merge register_TP and accept messages to a single message
    ?TRACE("tx_tm_rtm:on(~p) as ~p~n", [Msg, Role]),
    {ErrCodeTx, TmpTxState} = my_get_tx_entry(Tid, State),
    _ = case ok =/= ErrCodeTx of
        true -> %% new / uninitialized
            %% hold back and handle when corresponding tx_state is
            %% created in init_RTM
            %% io:format("Holding back a registerTP for id ~p in ~p~n", [Tid, Role]),
            T2TxState = tx_state:hold_back(Msg, TmpTxState),
            NewTxState = tx_state:set_status(T2TxState, uninitialized),
            msg_delay:send_local((config:read(tx_timeout) * 3) div 1000, self(),
                                 {tx_tm_rtm_delete_txid, Tid}),
            my_set_entry(NewTxState, State);
        false -> %% ok
            TxState = tx_state:inc_numtpsregistered(TmpTxState),
            _ = my_set_entry(TxState, State),
            {ok, ItemState} = my_get_item_entry(ItemId, State),

            case {tx_state:is_decided(TxState), Role} of
                {undecided, _} ->
                    %% store TP info to corresponding PaxosId
                    NewEntry =
                        tx_item_state:set_tp_for_paxosid(ItemState, TP, PaxosID),
                    my_trigger_delete_if_done(TxState),
                    my_set_entry(NewEntry, State);
                {Decision, tx_tm} ->
                    %% if register_TP arrives after tx decision, inform the
                    %% slowly client directly
                    %% find matching RTLogEntry and send commit_reply
                    {PaxosID, RTLogEntry, _TP} =
                        lists:keyfind(PaxosID, 1,
                          tx_item_state:get_paxosids_rtlogs_tps(ItemState)),
                    msg_commit_reply(TP, {PaxosID, RTLogEntry}, Decision),
                    %% record in txstate and try to delete entry?
                    NewTxState = tx_state:inc_numinformed(TxState),
                    my_trigger_delete_if_done(NewTxState),
                    my_set_entry(NewTxState, State);
                _ ->
                    %% RTMs check whether everything is done
                    my_trigger_delete_if_done(TxState)
            end
    end,
    State;

% timeout on Tid maybe a proposer crashed? Force proposals with abort.
on({tx_tm_rtm_propose_yourself, Tid},
   {_RTMs, _TableName, Role, _LAcceptor, GLLearner} = State) ->
    ?TRACE("tx_tm_rtm:propose_yourself(~p) as ~p~n", [Tid, _Role]),
    %% after timeout take over and initiate new paxos round as proposer
    {ErrCodeTx, TxState} = my_get_tx_entry(Tid, State),
    _ =
    case ErrCodeTx of
        new -> ok; %% takeover is not necessary. Was finished successfully.
        _Any ->
            log:log(warn, "Takeover by RTM was necessary."),
            Maj = config:read(quorum_factor),
            RTMs = tx_state:get_rtms(TxState),
            Accs = rtms_get_accpids(RTMs),
            {_, _, ThisRTMsNumber, _} = lists:keyfind(comm:this(), 2, RTMs),

            %% add ourselves as learner and
            %% trigger paxos proposers for new round with own proposal 'abort'
            {_, TxItemIDs} = lists:unzip(tx_state:get_tlog_txitemids(TxState)),
            [ begin
                  {_, ItemState} = my_get_item_entry(ItemId, State),
                  case tx_item_state:get_decided(ItemState) of
                      false ->
                          [ begin
                                learner:start_paxosid(GLLearner, PaxId, Maj,
                                                      comm:this(), ItemId),
                                %% add learner to running paxos acceptors
                                _ = [ comm:send(Acc,
                                                {acceptor_add_learner, PaxId, GLLearner})
                                      || Acc <- Accs],

                                Proposer =
                                    comm:make_global(get_my(Role, proposer)),
                                proposer:start_paxosid(
                                  Proposer, PaxId, _Acceptors = Accs, abort,
                                  Maj, length(Accs) + 1, ThisRTMsNumber),
                                ok
                            end
                            || {PaxId, _RTLog, _TP}
                                   <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ];
                      _Decision -> % already decided to prepared / abort
                          ok
                  end
              end || ItemId <- TxItemIDs ]
        end,
    State;

%% failure detector events
on({crash, Pid},
   {RTMs, _TableName, _Role, _LAcceptor, _GLLearner} = State) ->
    ?TRACE_RTM_MGMT("tx_tm_rtm:on({crash,...}) of Pid ~p~n", [Pid]),
    ct:pal("tx_tm_rtm:on({crash,...}) of Pid ~p~n", [Pid]),
    _ = [ begin
              Name = get_nth_rtm_name(get_nth(RTM)),
              Key = get_rtmkey(RTM),
              api_dht_raw:unreliable_lookup(
                Key, {get_rtm, comm:this(), Key, Name})
          end
      || RTM <- RTMs, get_rtmpid(RTM) =:= Pid ],
    State;

on({crash, _Pid, _Cookie},
   {_RTMs, _TableName, _Role, _LAcceptor, _GLLearner} = State) ->
    ?TRACE("tx_tm_rtm:on:crash of ~p in Transaction ~p~n", [_Pid, binary_to_term(_Cookie)]),
    %% @todo should we take over, if the TM failed?
    %% Takeover done by timeout (propose yourself). Doing it here could
    %% improve speed, but really necessary!?
    %%
    %% for all Tids make a fold with
    %% NewState = lists:foldr(fun(X, XState) ->
    %%   on({tx_tm_rtm_propose_yourself, Tid}, XState)
    %%                        end, State, listwithalltids),
    State;

on({new_node_id, Id}, {RTMs, TableName, tx_tm, LAcceptor, GLLearner}) ->
    IDs = ?RT:get_replica_keys(Id),
    NewRTMs = [ set_rtmkey(R, I) || {R, I} <- lists:zip(RTMs, IDs) ],
    {NewRTMs, TableName, tx_tm, LAcceptor, GLLearner};
%% periodic RTM update
on({update_RTMs},
   {RTMs, _TableName, tx_tm, _LAcceptor, _GLLearner} = State) ->
    ?TRACE_RTM_MGMT("tx_tm_rtm:on:update_RTMs in Pid ~p ~n", [self()]),
    my_RTM_update(RTMs),
    State;

%% accept RTM updates
on({get_rtm_reply, InKey, InPid, InAcceptor},
   {RTMs, TableName, tx_tm, LAcceptor, GLLearner} = _State) ->
    ?TRACE_RTM_MGMT("tx_tm_rtm:on:get_rtm_reply in Pid ~p for Pid ~p and State ~p~n", [self(), InPid, _State]),
    NewRTMs = rtms_upd_entry(RTMs, InKey, InPid, InAcceptor),
    rtms_of_same_dht_node(NewRTMs),
    {NewRTMs, TableName, tx_tm, LAcceptor, GLLearner}.

-spec on_init(comm:message(), state_uninit())
    -> state_uninit() |
       {'$gen_component', [{on_handler, Handler::on}], State::state()}.
%% While initializing
on_init({get_node_details_response, NodeDetails},
        {_RTMs, TableName, tx_tm, LAcceptor, GLLearner, QueuedMessages} = _State) ->
    ?TRACE("tx_tm_rtm:on_init:get_node_details_response State; ~p~n", [_State]),
    IdSelf = node:id(node_details:get(NodeDetails, node)),
    %% provide ids for RTMs (sorted by increasing latency to them).
    %% first entry is the locally hosted replica of IdSelf
    RTM_ids = ?RT:get_replica_keys(IdSelf),
    {NewRTMs, _} = lists:foldr(
                fun(X, {Acc, I}) ->
                        {[rtm_entry_new(X, unknown, I, unknown) | Acc ], I - 1}
                end,
                {[], length(RTM_ids) - 1}, RTM_ids),
    my_RTM_update(NewRTMs),
    {NewRTMs, TableName, tx_tm, LAcceptor, GLLearner, QueuedMessages};

on_init({update_RTMs},
        {RTMs, _TableName, tx_tm, _LAcceptor, _GLLearner, _QueuedMessages} = State) ->
    ?TRACE_RTM_MGMT("tx_tm_rtm:on_init:update_RTMs in Pid ~p ~n", [self()]),
    my_RTM_update(RTMs),
    State;

on_init({get_rtm_reply, InKey, InPid, InAcceptor},
        {RTMs, TableName, tx_tm, LAcceptor, GLLearner, QueuedMessages} = _State) ->
    ?TRACE_RTM_MGMT("tx_tm_rtm:on_init:get_rtm_reply in Pid ~p for Pid ~p State ~p~n", [self(), InPid, _State]),
    NewRTMs = rtms_upd_entry(RTMs, InKey, InPid, InAcceptor),
    case lists:keyfind(unknown, 2, NewRTMs) of %% filled all entries?
        false ->
            rtms_of_same_dht_node(NewRTMs),
            msg_queue:send(QueuedMessages),
            gen_component:change_handler(
              {NewRTMs, TableName, tx_tm, LAcceptor, GLLearner}, on);
        _ -> {NewRTMs, TableName, tx_tm, LAcceptor, GLLearner, QueuedMessages}
    end;

on_init({new_node_id, Id}, {RTMs, TableName, tx_tm, LAcceptor, GLLearner, Queue}) ->
    IDs = ?RT:get_replica_keys(Id),
    NewRTMs = [ set_rtmkey(R, I) || {R, I} <- lists:zip(RTMs, IDs) ],
    {NewRTMs, TableName, tx_tm, LAcceptor, GLLearner, Queue};

on_init({tx_tm_rtm_commit, _Client, _ClientsID, _TransLog} = Msg,
        {RTMs, TableName, tx_tm, LAcceptor, GLLearner, QueuedMessages} = _State) ->
    NewQueuedMessages = msg_queue:add(QueuedMessages, Msg),
    {RTMs, TableName, tx_tm, LAcceptor, GLLearner, NewQueuedMessages}.

%% functions for periodic RTM updates
-spec my_RTM_update(rtms()) -> ok.
my_RTM_update(RTMs) ->
    _ = [ begin
              Name = get_nth_rtm_name(get_nth(RTM)),
              Key = get_rtmkey(RTM),
              api_dht_raw:unreliable_lookup(Key, {get_rtm, comm:this(), Key, Name})
          end
          || RTM <- RTMs],
    comm:send_local_after(config:read(tx_rtm_update_interval),
                          self(), {update_RTMs}),
    ok.

%% functions for tx processing
-spec my_start_fds_for_tid(tx_state:tx_id(), tx_state:tx_state()) -> ok.
my_start_fds_for_tid(Tid, TxEntry) ->
    ?TRACE("tx_tm_rtm:my_start_fds_for_tid~n", []),
    RTMs = tx_state:get_rtms(TxEntry),
    RTMGPids = rtms_get_rtmpids(RTMs),
    fd:subscribe(RTMGPids, Tid).

-spec my_stop_fds_for_tid(tx_state:tx_id(), tx_state:tx_state()) -> ok.
my_stop_fds_for_tid(Tid, TxEntry) ->
    ?TRACE("tx_tm_rtm:my_stop_fds_for_tid~n", []),
    RTMs = tx_state:get_rtms(TxEntry),
    RTMGPids = rtms_get_rtmpids(RTMs),
    fd:unsubscribe(RTMGPids, Tid).

-spec my_init_RTMs(tx_state:tx_state(), [tx_item_state:tx_item_state()]) -> ok.
my_init_RTMs(TxState, ItemStates) ->
    ?TRACE("tx_tm_rtm:my_init_RTMs~n", []),
    RTMs = tx_state:get_rtms(TxState),
    _ = [ comm:send(get_rtmpid(RTM),
                    {tx_tm_rtm_init_RTM, TxState, ItemStates, get_nth(RTM)})
      || RTM <- RTMs ],
    ok.

-spec my_init_TPs(tx_state:tx_state(), [tx_item_state:tx_item_state()]) -> ok.
my_init_TPs(TxState, ItemStates) ->
    ?TRACE("tx_tm_rtm:my_init_TPs~n", []),
    %% send to each TP its own record / request including the RTMs to
    %% be used
    Tid = tx_state:get_tid(TxState),
    RTMs = tx_state:get_rtms(TxState),
    CleanRTMs = rtms_get_rtmpids(RTMs),
    Accs = rtms_get_accpids(RTMs),
    TM = comm:this(),
    _ = [ begin
          %% ItemState = lists:keyfind(ItemId, 1, ItemStates),
          ItemId = tx_item_state:get_itemid(ItemState),
          [ begin
                Key = tx_tlog:get_entry_key(RTLog),
                Msg1 = {init_TP, {Tid, CleanRTMs, Accs, TM, RTLog, ItemId, PaxId}},
                %% delivers message to a dht_node process, which has
                %% also the role of a TP
                api_dht_raw:unreliable_lookup(Key, Msg1)
            end
            || {PaxId, RTLog, _TP} <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ]
              %%      end || {_TLogEntry, ItemId} <- tx_state:get_tlog_txitemids(TxState) ],
      end || ItemState <- ItemStates ],
    ok.

-spec my_get_tx_entry(tx_state:tx_id(), state())
                     -> {new | ok | uninitialized, tx_state:tx_state()}.
my_get_tx_entry(Id,
                {_RTMs, TableName, _Role, _LAcceptor, _GLLearner} = _State) ->
    case pdb:get(Id, TableName) of
        undefined -> {new, tx_state:new(Id)};
        Entry -> {tx_state:get_status(Entry), Entry}
    end.

-spec my_get_item_entry(tx_item_state:tx_item_id(), state()) ->
                               {new | uninitialized | ok,
                                tx_item_state:tx_item_state()}.
my_get_item_entry(Id, {_RTMs, TableName, _Role, _LAcceptor, _GLLearner} = _State) ->
    case pdb:get(Id, TableName) of
        undefined -> {new, tx_item_state:new(Id)};
        Entry -> {tx_item_state:get_status(Entry), Entry}
    end.

-spec my_set_entry(tx_state:tx_state() | tx_item_state:tx_item_state(),
                   state()) -> state().
my_set_entry(NewEntry, {_RTMs, TableName, _Role, _LAcceptor, _GLLearner} = State) ->
    pdb:set(NewEntry, TableName),
    State.

-spec my_inform_client(tx_state:tx_id(), state(), commit | abort) -> ok.
my_inform_client(TxId, State, Result) ->
    ?TRACE("tx_tm_rtm:inform client~n", []),
    {ok, TxState} = my_get_tx_entry(TxId, State),
    Client = tx_state:get_client(TxState),
    ClientsId = tx_state:get_clientsid(TxState),
    case Client of
        unknown -> ok;
        _ -> msg_commit_reply(Client, ClientsId, Result)
    end,
    ok.

-spec my_inform_tps(tx_state:tx_state(), state(), commit | abort) ->
                           tx_state:tx_state().
my_inform_tps(TxState, State, Result) ->
    ?TRACE("tx_tm_rtm:inform tps~n", []),
    %% inform TPs
    X = [ begin
              {ok, ItemState} = my_get_item_entry(ItemId, State),
              [ case comm:is_valid(TP) of
                    false -> unknown;
                    true -> msg_commit_reply(TP, {PaxId, RTLogEntry}, Result), ok
                end
                || {PaxId, RTLogEntry, TP}
                       <- tx_item_state:get_paxosids_rtlogs_tps(ItemState) ]
          end || {_TLogEntry, ItemId} <- tx_state:get_tlog_txitemids(TxState) ],
    Y = [ Z || Z <- lists:flatten(X), Z =:= ok ],
    NewTxState = tx_state:set_numinformed(TxState, length(Y)),
%%    my_trigger_delete_if_done(NewTxState),
    NewTxState.

-spec my_inform_rtms(tx_state:tx_id(), state(), commit | abort) -> ok.
my_inform_rtms(_TxId, _State, _Result) ->
    ?TRACE("tx_tm_rtm:inform rtms~n", []),
    %%{ok, TxState} = my_get_tx_entry(_TxId, _State),
    %% @TODO inform RTMs?
    %% msg_commit_reply(Client, ClientsId, Result)
    ok.

-spec my_trigger_delete_if_done(tx_state:tx_state()) -> ok.
my_trigger_delete_if_done(TxState) ->
    ?TRACE("tx_tm_rtm:trigger delete?~n", []),
    case (tx_state:is_decided(TxState)) of
        undecided -> ok;
        false -> ok;
        Decision -> %% commit / abort
            %% @TODO majority informed is sufficient?!
            case tx_state:all_tps_informed(TxState)
                %%        andalso tx_state:all_pax_decided(TxState)
                %%    andalso tx_state:all_tps_registered(TxState)
            of
                true ->
                    TxId = tx_state:get_tid(TxState),
                    comm:send_local(self(), {tx_tm_rtm_delete, TxId, Decision});
                false -> ok
            end
    end, ok.

-spec rtms_of_same_dht_node(rtms()) -> boolean().
rtms_of_same_dht_node(InRTMs) ->
    Groups = lists:usort([catch(pid_groups:group_of(
                                  comm:make_local(get_rtmpid(X))))
                          || X <- InRTMs]),
    case length(Groups) of
        4 -> false;
        _ ->
            log:log(info, "RTMs of same DHT node are used. Please start more Scalaris nodes.~n"),
            true
    end.

rtm_entry_new(Key, RTMPid, Nth, AccPid) -> {Key, RTMPid, Nth, AccPid}.
get_rtmkey(RTMEntry) -> element(1, RTMEntry).
set_rtmkey(RTMEntry, Val) -> setelement(1, RTMEntry, Val).
get_rtmpid(RTMEntry) -> element(2, RTMEntry).
get_nth(RTMEntry)    -> element(3, RTMEntry).
get_accpid(RTMEntry) -> element(4, RTMEntry).

rtms_get_rtmpids(RTMs) -> [ get_rtmpid(X) || X <- RTMs ].
rtms_get_accpids(RTMs) -> [ get_accpid(X) || X <- RTMs ].

-spec rtms_upd_entry(rtms(), ?RT:key(), comm:mypid(), comm:mypid()) -> rtms().
rtms_upd_entry(RTMs, InKey, InPid, InAccPid) ->
    [ case InKey =:= get_rtmkey(Entry) of
          true ->
              RTM = get_rtmpid(Entry),
              case InPid =/= RTM of
                  true -> case RTM of
                              unknown -> ok;
                              _ -> fd:unsubscribe(RTM)
                          end,
                          fd:subscribe(InPid);
                  false -> ok
              end,
              rtm_entry_new(InKey, InPid, get_nth(Entry), InAccPid);
          false -> Entry
      end || Entry <- RTMs ].


-spec get_nth_rtm_name(pos_integer()) -> atom(). %% pid_groups:pidname().
get_nth_rtm_name(Nth) ->
    list_to_existing_atom("tx_rtm" ++ integer_to_list(Nth)).

-spec get_my(pid_groups:pidname(), atom()) -> pid() | failed.
get_my(Role, PaxosRole) ->
    PidName = list_to_existing_atom(
                atom_to_list(Role) ++ "_" ++ atom_to_list(PaxosRole)),
    pid_groups:get_my(PidName).

%% @doc Checks whether config parameters for tx_tm_rtm exist and are
%%      valid.
-spec check_config() -> boolean().
check_config() ->
    config:is_integer(quorum_factor) and
    config:is_greater_than(quorum_factor, 0) and
    config:is_integer(replication_factor) and
    config:is_greater_than(replication_factor, 0) and

    config:is_integer(tx_timeout) and
    config:is_greater_than(tx_timeout, 0) and
    config:is_integer(tx_rtm_update_interval) and
    config:is_greater_than(tx_rtm_update_interval, 0) and

    config:is_greater_than_equal(tx_timeout, 1000/3)
%%     config:is_greater_than_equal(tx_timeout, 1000/2)
    .

