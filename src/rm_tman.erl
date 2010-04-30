%  @copyright 2009-2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

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

%%% @author Christian Hennig <hennig@zib.de>
%%% @doc    T-Man ring maintenance
%%% @end
%% @version $Id$
-module(rm_tman).
-author('hennig@zib.de').
-vsn('$Id$ ').

-include("scalaris.hrl").

-behavior(gen_component).
-behavior(rm_beh).

-export([start_link/1]).
-export([init/1, on/2]).

-export([get_base_interval/0, get_min_interval/0, get_max_interval/0,
         check_config/0]).

% unit testing
-export([merge/3]).

-type(state() :: {Id             :: ?RT:key(),
                  Me             :: node:node_type(),
                  Preds          :: list(node:node_type()),
                  Succs          :: list(node:node_type()),
                  RandomViewSize :: pos_integer(),
                  Interval       :: pos_integer(),
                  TriggerState   :: trigger:state(),
                  Cache          :: list(node:node_type()), % random cyclon nodes
                  Churn          :: boolean()}
     | {uninit, TriggerState :: trigger:state()}).

% accepted messages
-type(message() ::
    {init, Id::?RT:key(), Me::node_details:node_type(), Predecessor::node_details:node_type(), SuccList::[node:node_type(),...]} |
    {get_succlist, Pid::cs_send:erl_local_pid()} |
    {get_predlist, Pid::cs_send:erl_local_pid()} |
    {trigger} |
    {cy_cache, Cache::[node:node_type()]} |
    {rm_buffer, OtherNode::node:node_type(), OtherBuffer::[node:node_type(),...]} |
    {rm_buffer_response, OtherBuffer::[node:node_type(),...]} |
    {zombie, Node::node:node_type()} |
    {crash, DeadPid::cs_send:mypid()} |
    {'$gen_cast', {debug_info, Requestor::cs_send:erl_local_pid()}} |
    {check_ring, Token::non_neg_integer(), Master::node:node_type()} |
    {init_check_ring, Token::non_neg_integer()} |
    {notify_new_pred, Pred::node:node_type()} |
    {notify_new_succ, Succ::node:node_type()}).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Startup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Starts a chord-like ring maintenance process, registers it with the
%%      process dictionary and returns its pid for use by a supervisor.
-spec start_link(instanceid()) -> {ok, pid()}.
start_link(InstanceId) ->
    Trigger = config:read(ringmaintenance_trigger),
    gen_component:start_link(?MODULE, Trigger, [{register, InstanceId, ring_maintenance}]).

%% @doc Initialises the module with an uninitialized state.
-spec init(module()) -> {uninit, TriggerState::trigger:state()}.
init(Trigger) ->
    log:log(info,"[ RM ~p ] starting ring maintainer TMAN~n", [cs_send:this()]),
    TriggerState = trigger:init(Trigger, ?MODULE),
    cs_send:send_local(get_pid_dnc() , {subscribe, self()}),
    cs_send:send_local(get_cs_pid(), {init_rm,self()}),
    {uninit, TriggerState}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal Loop
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

% @doc the Token takes care, that there is only one timermessage for stabilize
-spec on(message(), state()) -> state().
on({init, Id, Me, Predecessor, SuccList}, {uninit, TriggerState}) ->
    rm_beh:update_preds_and_succs([Predecessor], SuccList),
    fd:subscribe(lists:usort([node:pidX(Node) || Node <- [Predecessor | SuccList]])),
    cyclon:get_subset_rand_next_interval(1),
    NewTriggerState = trigger:first(TriggerState),
    {Id, Me, [Predecessor], SuccList, config:read(cyclon_cache_size),
     stabilizationInterval_min(), NewTriggerState, [], true};

on(Msg, {uninit, _TriggerState} = State) ->
    cs_send:send_local_after(100, self(), Msg),
    State;

on({get_succlist, Pid},
   {_Id, Me, _Preds, [], _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    cs_send:send_local(Pid , {get_succlist_response, [Me]}),
    State;

on({get_succlist, Pid},
   {_Id, _Me, _Preds, Succs, _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    cs_send:send_local(Pid, {get_succlist_response, Succs}),
    State;

on({get_predlist, Pid},
   {_Id, Me, [], _Succs, _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    cs_send:send_local(Pid , {get_predlist_response, [Me]}),
    State;

on({get_predlist, Pid},
   {_Id, _Me, Preds, _Succs, _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    cs_send:send_local(Pid , {get_predlist_response, Preds}),
    State;

% start gossip
on({trigger},
   {Id, Me, Preds, Succs, RandViewSize, Interval, TriggerState, Cache, Churn}) ->
    % Triger an update of the Random view
    %
    RndView= get_RndView(RandViewSize, Cache),
    %log:log(debug, " [RM | ~p ] RNDVIEW: ~p", [self(),RndView]),
    {Pred,Succ} = get_safe_pred_succ(Preds,Succs,RndView,Me),
            %io:format("~p~n",[{Preds,Succs,RndView,Me}]),
            %Test for being alone
    NewTriggerState =
        case ((Pred == Me) and (Succ == Me)) of
            true ->
                rm_beh:update_preds([Me]),
                rm_beh:update_succs([Me]),
                TriggerState;
            false ->
                Message = {rm_buffer, Me, Succs ++ Preds ++ [Me]},
                cs_send:send_to_group_member(node:pidX(Succ), ring_maintenance,
                                             Message),
                cs_send:send_to_group_member(node:pidX(Pred), ring_maintenance,
                                             Message),
                trigger:next(TriggerState, base_interval)
        end,
   {Id, Me, Preds, Succs, RandViewSize, Interval, NewTriggerState, Cache, Churn};

% got empty cyclon cache
on({cy_cache, []},
   {_Id, _Me, _Preds, _Succs, RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State)  ->
    % ignore empty cache from cyclon
    cyclon:get_subset_rand_next_interval(RandViewSize),
    State;

% got cyclon cache
on({cy_cache, NewCache},
   {Id, Me, OldPreds, OldSuccs, RandViewSize, Interval, TriggerState, _Cache, Churn}) ->
             %inc RandViewSize (no error detected)
    RandViewSizeNew =
        case (RandViewSize < config:read(cyclon_cache_size)) of
            true  -> RandViewSize + 1;
            false -> RandViewSize
        end,
    % trigger new cyclon cache request
    cyclon:get_subset_rand_next_interval(RandViewSizeNew),
    RndView = get_RndView(RandViewSizeNew, NewCache),
    {NewPreds, NewSuccs, NewInterval, NewChurn} =
        update_view(OldPreds, OldSuccs, NewCache, RndView, Me, Interval, Churn),
    {Id, Me, NewPreds, NewSuccs, RandViewSizeNew, NewInterval, TriggerState,
     NewCache, NewChurn};

% got shuffle request
on({rm_buffer, OtherNode, OtherBuffer},
   {Id, Me, OldPreds, OldSuccs, RandViewSize, Interval, TriggerState ,Cache, Churn}) ->
    RndView = get_RndView(RandViewSize, Cache),
    cs_send:send_to_group_member(node:pidX(OtherNode), ring_maintenance,
                                 {rm_buffer_response, OldSuccs ++ OldPreds ++ [Me]}),
    {NewPreds, NewSuccs, NewInterval, NewChurn} =
        update_view(OldPreds, OldSuccs, OtherBuffer, RndView, Me, Interval, Churn),
    NewTriggerState = trigger:next(TriggerState, NewInterval),
    {Id, Me, NewPreds, NewSuccs, RandViewSize, NewInterval, NewTriggerState, Cache, NewChurn};

on({rm_buffer_response, OtherBuffer},
   {Id, Me, OldPreds, OldSuccs, RandViewSize, Interval, TriggerState, Cache, Churn}) ->
    RndView = get_RndView(RandViewSize, Cache),
    {NewPreds, NewSuccs, NewInterval, NewChurn} =
        update_view(OldPreds, OldSuccs, OtherBuffer, RndView, Me, Interval, Churn),
    %inc RandViewSize (no error detected)
    NewRandViewSize =
        case RandViewSize < config:read(cyclon_cache_size) of
            true ->  RandViewSize + 1;
            false -> RandViewSize
        end,
    NewTriggerState = trigger:next(TriggerState, NewInterval),
    {Id, Me, NewPreds, NewSuccs, NewRandViewSize, NewInterval, NewTriggerState, Cache, NewChurn};

% dead-node-cache reported dead node to be alive again
on({zombie, Node}, {Id, Me, Preds, Succs, RandViewSize, _Interval, TriggerState, Cache, Churn})  ->
    NewTriggerState = trigger:next(TriggerState, now_and_min_interval),
    {Id, Me, Preds, Succs, RandViewSize, stabilizationInterval_min(), NewTriggerState, [Node|Cache], Churn};

% failure detector reported dead node
on({crash, DeadPid},
   {Id, Me, OldPreds, OldSuccs, _RandViewSize, _Interval, TriggerState, Cache, Churn}) ->
    NewPreds = filter(DeadPid, OldPreds),
    NewSuccs = filter(DeadPid, OldSuccs),
    NewCache = filter(DeadPid, Cache),
    update_dht_node(OldPreds, NewPreds, OldSuccs, NewSuccs),
    update_failuredetector(OldPreds, NewPreds, OldSuccs, NewSuccs),
    NewTriggerState = trigger:next(TriggerState, now_and_min_interval),
    {Id, Me, NewPreds, NewSuccs, 0, stabilizationInterval_min(), NewTriggerState, NewCache,Churn};

on({'$gen_cast', {debug_info, Requestor}},
   {_Id, _Me, Preds, Succs, _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    cs_send:send_local(Requestor,
                       {debug_info_response,
                        [{"pred", lists:flatten(io_lib:format("~p", [Preds]))},
                         {"succs", lists:flatten(io_lib:format("~p", [Succs]))}]}),
    State;

% trigger by admin:dd_check_ring
on({check_ring, Token, Master},
   {_Id,  Me, Preds, Succs, _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    case {Token, Master} of
        {0, Me} ->
            io:format(" [RM ] CheckRing   OK  ~n");
        {0, _} ->
            io:format(" [RM ] CheckRing  reach TTL in Node ~p not in ~p~n",[Master, Me]);
        {Token, Me} ->
            io:format(" [RM ] Token back with Value: ~p~n",[Token]);
        {Token, _} ->
            {Pred, _Succ} = get_safe_pred_succ(Preds, Succs, [], Me),
            cs_send:send_to_group_member(node:pidX(Pred), ring_maintenance,
                                         {check_ring, Token-1, Master})
    end,
    State;

% trigger by admin:dd_check_ring
on({init_check_ring,Token},
   {_Id, Me, Preds, Succs, _RandViewSize, _Interval, _TriggerState, _Cache, _Churn} = State) ->
    {Pred, _Succ} = get_safe_pred_succ(Preds, Succs, [], Me),
    cs_send:send_to_group_member(node:pidX(Pred), ring_maintenance,
                                 {check_ring, Token - 1, Me}),
    State;

on({notify_new_pred, _NewPred}, State) ->
    %% @TODO use the new predecessor info
    State;

on({notify_new_succ, _NewSucc}, State) ->
    %% @TODO use the new successor info
    State;

on(_, _State) ->
    unknown_event.

%% @doc Checks whether config parameters of the rm_tman process exist and are
%%      valid.
-spec check_config() -> boolean().
check_config() ->
    config:is_atom(ringmaintenance_trigger) and

    config:is_integer(stabilization_interval_base) and
    config:is_greater_than(stabilization_interval_base, 0) and

    config:is_integer(stabilization_interval_min) and
    config:is_greater_than(stabilization_interval_min, 0) and
    config:is_greater_than_equal(stabilization_interval_base, stabilization_interval_min) and

    config:is_integer(stabilization_interval_max) and
    config:is_greater_than(stabilization_interval_max, 0) and
    config:is_greater_than_equal(stabilization_interval_max, stabilization_interval_min) and
    config:is_greater_than_equal(stabilization_interval_max, stabilization_interval_base) and

    config:is_integer(cyclon_cache_size) and
    config:is_greater_than(cyclon_cache_size, 2) and

    config:is_integer(succ_list_length) and
    config:is_greater_than_equal(succ_list_length, 0) and

    config:is_integer(pred_list_length) and
    config:is_greater_than_equal(pred_list_length, 0).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Internal Functions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc merge two successor lists into one
%%      and sort by identifier
-spec merge([node:node_type()], [node:node_type()], ?RT:key()) -> [node:node_type()].
merge(L1, L2, Id) ->
    MergedList = lists:append(L1, L2),
    Order = fun(A, B) ->
                    node:id(A) =< node:id(B)
            end,
    Larger  = lists:usort(Order, [X || X <- MergedList, node:id(X) >  Id]),
    Equal   = lists:usort(Order, [X || X <- MergedList, node:id(X) == Id]),
    Smaller = lists:usort(Order, [X || X <- MergedList, node:id(X) <  Id]),
    A = lists:append([Larger, Smaller]),
    case A of
        [] -> Equal;
        _  -> A
    end.

-spec filter(cs_send:mypid(), [node:node_type()]) -> [node:node_type()].
filter(_Pid, []) ->
    [];
filter(Pid, [Succ | Rest]) ->
    case Pid == node:pidX(Succ) of
        true ->
            %Hook for DeadNodeCache
            dn_cache:add_zombie_candidate(Succ),
            filter(Pid, Rest);
        false ->
            [Succ | filter(Pid, Rest)]
    end.

%% @doc get a peer form the cycloncache which is alive
-spec get_RndView(integer(), [node:node_type()]) -> [node:node_type()].
get_RndView(N, Cache) ->
    lists:sublist(Cache, N).

% @doc Check if change of failuredetector is necessary
-spec update_failuredetector(
        OldPreds::[node:node_type()], NewPreds::[node:node_type()],
        OldSuccs::[node:node_type()], NewSuccs::[node:node_type()]) ->
              ok.
update_failuredetector(OldPreds, NewPreds, OldSuccs, NewSuccs) ->
    OldView=lists:usort(OldPreds++OldSuccs),
    NewView=lists:usort(NewPreds++NewSuccs),
    case (NewView /= OldView) of
        true ->
            NewNodes = util:minus(NewView,OldView),
            OldNodes = util:minus(OldView,NewView),
            fd:unsubscribe([node:pidX(Node) || Node <- OldNodes]),
            fd:subscribe([node:pidX(Node) || Node <- NewNodes]),
            ok;
        false ->
            ok
    end.

% @doc inform the dht_node of new [succ|pred] if necessary
-spec update_dht_node(
        OldPreds::[node:node_type()], NewPreds::[node:node_type()],
        OldSuccs::[node:node_type()], NewSuccs::[node:node_type()]) ->
              {NewPreds::[node:node_type()], NewSuccs::[node:node_type()]}.
update_dht_node(OldPreds, NewPreds, OldSuccs, NewSuccs) ->
    %io:format("UCN: ~p ~n",[{PredsNew,SuccsNew,ShuffelBuddy,AktPred,AktSucc}]),
    case NewPreds =/= [] andalso OldPreds =/= NewPreds of
        true -> rm_beh:update_preds(NewPreds);
        false -> ok
    end,
    case NewSuccs =/= [] andalso OldSuccs =/= NewSuccs of
        true -> rm_beh:update_succs(NewSuccs);
        false -> ok
    end,
    {NewPreds, NewSuccs}.

-spec get_safe_pred_succ(
        Preds::[node:node_type()], Succs::[node:node_type()],
        RndView::[node:node_type()], Me::node:node_type()) ->
              {Pred::node:node_type(), Succ::node:node_type()}.
get_safe_pred_succ(Preds, Succs, RndView, Me) ->
    case (Preds == []) or (Succs == []) of
        true ->
            Buffer = merge(Preds ++ Succs, RndView,node:id(Me)),
            %io:format("Buffer: ~p~n",[Buffer]),
            case Buffer == [] of
                false ->
                    SuccsNew = lists:sublist(Buffer, 1, config:read(succ_list_length)),
                    PredsNew = lists:sublist(lists:reverse(Buffer), 1, config:read(pred_list_length)),
                    {hd(PredsNew), hd(SuccsNew)};
                true ->
                    {Me, Me}
            end;
        false ->
            {hd(Preds), hd(Succs)}
    end.

% @doc adapt the Tman-interval
-spec new_interval(
        OldPreds::[node:node_type()], NewPreds::[node:node_type()],
        OldSuccs::[node:node_type()], NewSuccs::[node:node_type()],
        Interval::trigger:interval(), Churn::boolean()) ->
              min_interval | max_interval.
new_interval(OldPreds, NewPreds, OldSuccs, NewSuccs, _Interval, Churn) ->
    case has_churn(OldPreds, NewPreds, OldSuccs, NewSuccs) orelse Churn of
        true ->
            % increasing the ring maintenance frequency
            min_interval;
        false ->
            max_interval
    end.

% @doc is there churn in the system
-spec has_churn(
        OldPreds::[node:node_type()], NewPreds::[node:node_type()],
        OldSuccs::[node:node_type()], NewSuccs::[node:node_type()]) ->
              boolean().
has_churn(OldPreds, NewPreds, OldSuccs, NewSuccs) ->
    not ((OldPreds =:= NewPreds) andalso (OldSuccs =:= NewSuccs)).

-spec get_pid_dnc() -> pid() | failed.
get_pid_dnc() ->
    process_dictionary:get_group_member(dn_cache).

% get Pid of assigned dht_node
-spec get_cs_pid() -> pid() | failed.
get_cs_pid() ->
    process_dictionary:get_group_member(dht_node).

-spec get_base_interval() -> pos_integer().
get_base_interval() ->
    config:read(stabilization_interval_base).

-spec get_min_interval() -> pos_integer().
get_min_interval() ->
    config:read(stabilization_interval_min).

-spec get_max_interval() -> pos_integer().
get_max_interval() ->
    config:read(stabilization_interval_max).

-spec update_view(
        OldPreds::[node:node_type()], OldSuccs::[node:node_type()],
        OtherBuffer::[node:node_type()], RndView::[node:node_type()],
        Me::node:node_type(), Interval::trigger:interval(), Churn::boolean()) ->
              {NewPreds::[node:node_type()], NewSuccs::[node:node_type()],
               NewInterval::trigger:interval(), NewChurn::boolean()}.
update_view(OldPreds, OldSuccs, OtherBuffer, RndView, Me, Interval, Churn) ->
    Buffer = merge(OldSuccs++OldPreds, OtherBuffer++RndView, node:id(Me)),
    NewSuccs = lists:sublist(Buffer, config:read(succ_list_length)),
    NewPreds = lists:sublist(lists:reverse(Buffer), config:read(pred_list_length)),
    update_dht_node(OldPreds, NewPreds, OldSuccs, NewSuccs),
    update_failuredetector(OldPreds, NewPreds, OldSuccs, NewSuccs),
    NewInterval = new_interval(OldPreds, NewPreds, OldSuccs, NewSuccs, Interval, Churn),
    NewChurn = has_churn(OldPreds, NewPreds, OldSuccs, NewSuccs),
    {NewPreds, NewSuccs, NewInterval, NewChurn}.

%% @doc the interval between two stabilization runs Min
-spec stabilizationInterval_min() -> pos_integer().
stabilizationInterval_min() ->
    config:read(stabilization_interval_min).
