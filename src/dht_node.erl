%  @copyright 2007-2011 Zuse Institute Berlin

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

%% @author Thorsten Schuett <schuett@zib.de>
%% @doc    dht_node main file
%% @end
%% @version $Id$
-module(dht_node).
-author('schuett@zib.de').
-vsn('$Id$').

-include("scalaris.hrl").
-behaviour(gen_component).

-export([start_link/2, on/2, on_join/2, init/1, trigger_known_nodes/0]).

-export([is_first/1, is_alive/1, is_alive_no_join/1]).

-ifdef(with_export_type_support).
-export_type([message/0]).
-endif.

-type(bulkowner_message() ::
      {bulk_owner, I::intervals:interval(), Msg::comm:message()} |
      {start_bulk_owner, I::intervals:interval(), Msg::comm:message()} |
      {bulkowner_deliver, Range::intervals:interval(), {bulk_read_entry, Issuer::comm:mypid()}}).

-type(database_message() ::
      {get_key, Source_PID::comm:mypid(), Key::?RT:key()} |
      {get_key, Source_PID::comm:mypid(), SourceId::any(), HashedKey::?RT:key()} |
      {delete_key, Source_PID::comm:mypid(), ClientsId::{delete_client_id, util:global_uid()}, Key::?RT:key()} |
      {drop_data, Data::list(db_entry:entry()), Sender::comm:mypid()} |
      {get_chunk, Source_PID::comm:mypid(), Interval::intervals:interval(), MaxChunkSize::pos_integer()} |
      {update_key_entry, Source_PID::comm:mypid(), HashedKey::?RT:key(), NewValue::?DB:value(), NewVersion::?DB:version()}).

-type(lookup_message() ::
      {lookup_aux, Key::?RT:key(), Hops::pos_integer(), Msg::comm:message()} |
      {lookup_fin, Key::?RT:key(), Hops::pos_integer(), Msg::comm:message()}).

-type(rt_message() ::
      {rt_update, RoutingTable::?RT:external_rt()}).

% accepted messages of dht_node processes
-type message() ::
    bulkowner_message() |
    database_message() |
    lookup_message() |
    dht_node_join:join_message() |
    rt_message() |
    dht_node_move:move_message() |
    {zombie, Node::node:node_type()} |
    {crash, DeadPid::comm:mypid()}.

%% @doc message handler
-spec on_join(message(), dht_node_join:join_state())
        -> dht_node_join:join_state() |
           {'$gen_component', [{on_handler, Handler::on}], dht_node_state:state()}.
on_join(Msg, State) ->
    dht_node_join:process_join_state(Msg, State).

-spec on(message(), dht_node_state:state()) -> dht_node_state:state() | kill.
%% Join messages (see dht_node_join.erl)
%% userdevguide-begin dht_node:join_message
on(Msg, State) when element(1, Msg) =:= join ->
    dht_node_join:process_join_msg(Msg, State);
% message with cookie for dht_node_join?
on({Msg, Cookie} = FullMsg, State) when
  is_tuple(Msg) andalso is_atom(element(1, Msg)) andalso
      (element(1, Msg) =:= join orelse
           Cookie =:= join orelse
           (is_tuple(Cookie) andalso element(1, Cookie) =:= join)) ->
    dht_node_join:process_join_msg(FullMsg, State);
%% userdevguide-end dht_node:join_message

% Move messages (see dht_node_move.erl)
on(Msg, State) when element(1, Msg) =:= move ->
    dht_node_move:process_move_msg(Msg, State);

% RM messages (see rm_loop.erl)
on(Msg, State) when element(1, Msg) =:= rm ->
    RMState = dht_node_state:get(State, rm_state),
    RMState1 = rm_loop:on(Msg, RMState),
    dht_node_state:set_rm(State, RMState1);
on(Msg, State) when element(1, Msg) =:= rm_trigger ->
    RMState = dht_node_state:get(State, rm_state),
    RMState1 = rm_loop:on(Msg, RMState),
    dht_node_state:set_rm(State, RMState1);
% message with cookie for rm_loop?
on({Msg, Cookie} = FullMsg, State) when
  is_tuple(Msg) andalso is_atom(element(1, Msg)) andalso
      (element(1, Msg) =:= rm orelse
           Cookie =:= rm orelse
           (is_tuple(Cookie) andalso element(1, Cookie) =:= rm)) ->
    RMState = dht_node_state:get(State, rm_state),
    RMState1 = rm_loop:on(FullMsg, RMState),
    dht_node_state:set_rm(State, RMState1);

%% Kill Messages
on({kill}, _State) ->
    kill;

on({leave}, State) ->
    dht_node_move:make_slide_leave(State);

on({churn}, _State) ->
    kill;

on({halt}, _State) ->
    util:sleep_for_ever();

on({die}, _State) ->
    SupDhtNodeId = erlang:get(my_sup_dht_node_id),
    SupDhtNode = pid_groups:get_my(sup_dht_node),
    util:supervisor_terminate_childs(SupDhtNode),
    ok = supervisor:terminate_child(main_sup, SupDhtNodeId),
    ok = supervisor:delete_child(main_sup, SupDhtNodeId),
    kill;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Finger Maintenance
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({rt_update, RoutingTable}, State) ->
    dht_node_state:set_rt(State, RoutingTable);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Transactions (see transactions/*.erl)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({get_process_in_group, Source_PID, Key, Process}, State) ->
    Pid = pid_groups:get_my(Process),
    GPid = comm:make_global(Pid),
    comm:send(Source_PID, {get_process_in_group_reply, Key, GPid}),
    State;

on({get_rtm, Source_PID, Key, Process}, State) ->
    MyGroup = pid_groups:my_groupname(),
    Pid = pid_groups:get_my(Process),
    SupTx = pid_groups:get_my(sup_dht_node_core_tx),
    NewPid = case {Pid, SupTx} of
                 {failed, failed} -> failed;
                 {failed, SupTx} ->
                     %% start, if necessary
                     RTM_desc = util:sup_worker_desc(
                                  Process, tx_tm_rtm, start_link,
                                  [MyGroup, Process]),
                     case supervisor:start_child(SupTx, RTM_desc) of
                         {ok, TmpPid} -> TmpPid;
                         {ok, TmpPid, _} -> TmpPid;
                         {error, {already_started, TmpPid}} -> TmpPid;
                         {error, Reason} ->
                             log:log(warn, "[ ~.0p ] tx_tm_rtm start_child failed: ~.0p~n",
                                     [comm:this(), Reason]),
                             msg_delay:send_local(1, self(), {get_rtm, Source_PID, Key, Process}),
                             failed
                     end;
                 _ -> Pid
             end,
    case NewPid of
        failed -> State;
        _ ->
            GPid = comm:make_global(NewPid),
            GPidAcc = comm:make_global(tx_tm_rtm:get_my(Process, acceptor)),
            comm:send(Source_PID, {get_rtm_reply, Key, GPid, GPidAcc}),
            State
    end;

%% messages handled as a transaction participant (TP)
on({init_TP, Params}, State) ->
    tx_tp:on_init_TP(Params, State);
on({tx_tm_rtm_commit_reply, Id, Result}, State) ->
    tx_tp:on_tx_commitreply(Id, Result, State);
on({tx_tm_rtm_commit_reply_fwd, RTLogEntry, Result, OwnProposal}, State) ->
    tx_tp:on_tx_commitreply_fwd(RTLogEntry, Result, OwnProposal, State);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Lookup (see api_dht_raw.erl and dht_node_look up.erl)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({lookup_aux, Key, Hops, Msg}, State) ->
    dht_node_lookup:lookup_aux(State, Key, Hops, Msg),
    State;

on(CompleteMsg = {lookup_fin, Key, Hops, Msg}, State) ->
    MsgFwd = dht_node_state:get(State, msg_fwd),
    FwdList = [P || {I, P} <- MsgFwd, intervals:in(Key, I)],
    case FwdList of
        []    ->
            case dht_node_state:is_db_responsible(Key, State) of
                true -> gen_component:post_op(State, Msg);
                false ->
                    % it is possible that we received the message due to a
                    % forward while sliding and before the other node removed
                    % the forward -> do not warn then
                    SlidePred = dht_node_state:get(State, slide_pred),
                    SlideSucc = dht_node_state:get(State, slide_succ),
                    Neighbors = dht_node_state:get(State, neighbors),
                    case ((SlidePred =/= null andalso
                               slide_op:get_sendORreceive(SlidePred) =:= 'send' andalso
                               intervals:in(Key, slide_op:get_interval(SlidePred)))
                         orelse
                              (SlideSucc =/= null andalso
                                   slide_op:get_sendORreceive(SlideSucc) =:= 'send' andalso
                                   intervals:in(Key, slide_op:get_interval(SlideSucc)))
                         orelse
                              intervals:in(Key, nodelist:succ_range(Neighbors))) of
                        true -> ok;
                        false ->
                            DBRange = dht_node_state:get(State, db_range),
                            DBRange2 = [begin
                                            case intervals:is_continuous(Interval) of
                                                true -> {intervals:get_bounds(Interval), Id};
                                                _    -> {Interval, Id}
                                            end
                                        end || {Interval, Id} <- DBRange],
                            log:log(warn,
                                    "[ ~.0p ] Routing is damaged!! Trying again...~n  myrange:~p~n  db_range:~p~n  msgfwd:~p~n  Key:~p",
                                    [self(), intervals:get_bounds(nodelist:node_range(Neighbors)),
                                     DBRange2, MsgFwd, Key])
                    end,
                    dht_node_lookup:lookup_aux(State, Key, Hops, Msg),
                    State
            end;
        [Pid] -> comm:send(Pid, CompleteMsg),
                 State
    end;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Database
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({get_key, Source_PID, HashedKey}, State) ->
    comm:send(Source_PID,
              {get_key_response, HashedKey,
               ?DB:read(dht_node_state:get(State, db), HashedKey)}),
    State;

on({get_key, Source_PID, SourceId, HashedKey}, State) ->
    Msg = {get_key_with_id_reply, SourceId, HashedKey,
           ?DB:read(dht_node_state:get(State, db), HashedKey)},
    comm:send(Source_PID, Msg),
    State;

on({get_chunk, Source_PID, Interval, MaxChunkSize}, State) ->
    Chunk = ?DB:get_chunk(dht_node_state:get(State, db), Interval, MaxChunkSize),
    comm:send_local(Source_PID, {get_chunk_response, Chunk}),
    State;

% @doc send caller update_key_entry_ack with Entry (if exists) or Key, Exists (Yes/No), Updated (Yes/No)
on({update_key_entry, Source_PID, HashedKey, NewValue, NewVersion}, State) ->    
    {Exists, Entry} = ?DB:get_entry2(dht_node_state:get(State, db), HashedKey),
    EntryVersion = db_entry:get_version(Entry),
    IsNewer = EntryVersion =/= -1 andalso EntryVersion < NewVersion,
    IsNotLocked = not db_entry:get_writelock(Entry),
    Updateable = IsNewer 
                     andalso IsNotLocked 
                     andalso dht_node_state:is_responsible(HashedKey, State),
    NewState = case Exists of
                   true when Updateable ->
                       UpdateEntry = db_entry:set_version(db_entry:set_value(Entry, NewValue), NewVersion),
                       NewDB = ?DB:update_entry(dht_node_state:get(State, db), UpdateEntry), 
                       dht_node_state:set_db(State, NewDB);
                   _ ->
                       State
               end,
    ResultMsg = case Exists of
                    true -> {update_key_entry_ack, Entry, true, Updateable};
                    _ -> {update_key_entry_ack, HashedKey, false, false}
                end,                    
    comm:send(Source_PID, ResultMsg),
    NewState;

%% for unit testing only: allow direct DB manipulation
on({get_key_entry, Source_PID, HashedKey}, State) ->
    Entry = ?DB:get_entry(dht_node_state:get(State, db), HashedKey),
    comm:send(Source_PID, {get_key_entry_reply, Entry}),
    State;

on({set_key_entry, Source_PID, Entry}, State) ->
    NewDB = ?DB:set_entry(dht_node_state:get(State, db), Entry),
    comm:send(Source_PID, {set_key_entry_reply, Entry}),
    dht_node_state:set_db(State, NewDB);

on({delete_key, Source_PID, ClientsId, HashedKey}, State) ->
    {DB2, Result} = ?DB:delete(dht_node_state:get(State, db), HashedKey),
    comm:send(Source_PID, {delete_key_response, ClientsId, HashedKey, Result}),
    dht_node_state:set_db(State, DB2);

on({drop_data, Data, Sender}, State) ->
    comm:send(Sender, {drop_data_ack}),
    DB = ?DB:add_data(dht_node_state:get(State, db), Data),
    dht_node_state:set_db(State, DB);

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Bulk owner messages (see bulkowner.erl)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({bulk_owner, I, Msg}, State) ->
    bulkowner:bulk_owner(State, I, Msg),
    State;

on({start_bulk_owner, I, Msg}, State) ->
    bulkowner:bulk_owner(State, I, Msg),
    State;

on({bulkowner_deliver, Range, {bulk_read_entry, Issuer}}, State) ->
    MsgFwd = dht_node_state:get(State, msg_fwd),

    F = fun({FwdInt, FwdPid}, AccI) ->
                case intervals:is_subset(FwdInt, AccI) of
                    true ->
                        FwdRange = intervals:intersection(AccI, FwdInt),
                        comm:send(FwdPid, {bulkowner_deliver, FwdRange, {bulk_read_entry, Issuer}}),
                        intervals:minus(AccI, FwdRange);
                    _    -> AccI
                end
        end,
    MyRange = lists:foldl(F, Range, MsgFwd),
    Data = ?DB:get_entries(dht_node_state:get(State, db), MyRange),
    comm:send(Issuer, {bulk_read_entry_response, MyRange, Data}),
    State;

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Misc.
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({get_yaws_info, Pid}, State) ->
    comm:send(Pid, {get_yaws_info_response, comm:get_ip(comm:this()), config:read(yaws_port), pid_groups:my_groupname()}),
    State;
on({get_state, Pid, Which}, State) ->
    comm:send(Pid, {get_state_response, dht_node_state:get(State, Which)}),
    State;
on({get_node_details, Pid}, State) ->
    comm:send(Pid, {get_node_details_response, dht_node_state:details(State)}),
    State;
on({get_node_details, Pid, Which}, State) ->
    comm:send(Pid, {get_node_details_response, dht_node_state:details(State, Which)}),
    State;

on({dump}, State) ->
    dht_node_state:dump(State),
    State;

on({web_debug_info, Requestor}, State) ->
    RMState = dht_node_state:get(State, rm_state),
    Load = dht_node_state:get(State, load),
    % get a list of up to 50 KV pairs to display:
    DataListTmp = [{"",
                    lists:flatten(io_lib:format("~p", [DBEntry]))}
                  || DBEntry <-
                         lists:sublist(?DB:get_data(dht_node_state:get(State, db)), 50)],
    DataList = case Load > 50 of
                   true  -> lists:append(DataListTmp, [{"...", ""}]);
                   false -> DataListTmp
               end,
    KVList1 =
        [{"rt_algorithm", lists:flatten(io_lib:format("~p", [?RT]))},
         {"rt_size", ?RT:get_size(dht_node_state:get(State, rt))},
         {"my_range", lists:flatten(io_lib:format("~p", [intervals:get_bounds(dht_node_state:get(State, my_range))]))},
         {"db_range", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, db_range)]))},
         {"load", lists:flatten(io_lib:format("~p", [Load]))},
         {"join_time", lists:flatten(io_lib:format("~p UTC", [calendar:now_to_universal_time(dht_node_state:get(State, join_time))]))},
%%          {"db", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, db)]))},
%%          {"proposer", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, proposer)]))},
         {"tx_tp_db", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, tx_tp_db)]))},
         {"slide_pred", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, slide_pred)]))},
         {"slide_succ", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, slide_succ)]))},
         {"msg_fwd", lists:flatten(io_lib:format("~p", [dht_node_state:get(State, msg_fwd)]))}
        ],
    KVList2 = lists:append(KVList1, [{"", ""} | rm_loop:get_web_debug_info(RMState)]),
    KVList3 = lists:append(KVList2, [{"", ""} , {"data (db_entry):", ""} | DataList]),
    comm:send_local(Requestor, {web_debug_info_reply, KVList3}),
    State;

on({unittest_get_bounds_and_data, SourcePid}, State) ->
    MyRange = dht_node_state:get(State, my_range),
    MyBounds = intervals:get_bounds(MyRange),
    Data = ?DB:get_data(dht_node_state:get(State, db)),
    Pred = dht_node_state:get(State, pred),
    Succ = dht_node_state:get(State, succ),
    comm:send(SourcePid, {unittest_get_bounds_and_data_response, MyBounds, Data, Pred, Succ}),
    State;

on({get_dht_nodes_response, _KnownHosts}, State) ->
    % will ignore these messages after join
    State;

% failure detector, dead node cache
on({crash, DeadPid}, State) ->
    RMState = dht_node_state:get(State, rm_state),
    RMState1 = rm_loop:crashed_node(RMState, DeadPid),
    % TODO: call other modules, e.g. join, move
    dht_node_state:set_rm(State, RMState1);

% dead-node-cache reported dead node to be alive again
on({zombie, Node}, State) ->
    RMState = dht_node_state:get(State, rm_state),
    RMState1 = rm_loop:zombie_node(RMState, Node),
    % TODO: call other modules, e.g. join, move
    dht_node_state:set_rm(State, RMState1).


%% userdevguide-begin dht_node:start
%% @doc joins this node in the ring and calls the main loop
-spec init(Options::[tuple()]) -> dht_node_state:state().
init(Options) ->
    {my_sup_dht_node_id, MySupDhtNode} = lists:keyfind(my_sup_dht_node_id, 1, Options),
    erlang:put(my_sup_dht_node_id, MySupDhtNode),
    % get my ID (if set, otherwise chose a random ID):
    Id = case lists:keyfind({dht_node, id}, 1, Options) of
             {{dht_node, id}, IdX} -> IdX;
             _ -> ?RT:get_random_node_id()
         end,
    case is_first(Options) of
        true -> dht_node_join:join_as_first(Id, 0, Options);
        _    -> dht_node_join:join_as_other(Id, 0, Options)
    end.
%% userdevguide-end dht_node:start

%% userdevguide-begin dht_node:start_link
%% @doc spawns a scalaris node, called by the scalaris supervisor process
-spec start_link(pid_groups:groupname(), [tuple()]) -> {ok, pid()}.
start_link(DHTNodeGroup, Options) ->
    gen_component:start_link(?MODULE, Options,
                             [{pid_groups_join_as, DHTNodeGroup, dht_node}, wait_for_init]).
%% userdevguide-end dht_node:start_link

%% @doc Find existing nodes and as a side-effect initialize the comm_layer.
-spec trigger_known_nodes() -> ok.
trigger_known_nodes() ->
    KnownHosts = config:read(known_hosts),
    % note, comm:this() may be invalid at this moment
    _ = [comm:send(KnownHost, {get_dht_nodes, comm:this()})
        || KnownHost <- KnownHosts],
    timer:sleep(100),
    case comm:is_valid(comm:this()) of
        true ->
            ok;
        false ->
            trigger_known_nodes()
    end.

%% @doc Checks whether this VM is marked as first, e.g. in a unit test, and
%%      this is the first node in this VM.
-spec is_first([tuple()]) -> boolean().
is_first(Options) ->
    lists:member({first}, Options) andalso admin_first:is_first_vm().

-spec is_alive(Pid::pid()) -> boolean().
is_alive(Pid) ->
    State = gen_component:get_state(Pid),
    erlang:is_tuple(State) andalso element(1, State) =:= state.

-spec is_alive_no_join(Pid::pid()) -> boolean().
is_alive_no_join(Pid) ->
    State = gen_component:get_state(Pid),
    try
        SlidePred = dht_node_state:get(State, slide_pred),
        SlideSucc = dht_node_state:get(State, slide_succ),
        (SlidePred =:= null orelse not slide_op:is_join(SlidePred)) andalso
            (SlideSucc =:= null orelse not slide_op:is_join(SlideSucc))
    catch _:_ -> false
    end.
