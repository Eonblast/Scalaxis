% @copyright 2011 Zuse Institute Berlin

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

%% @author Maik Lange <malange@informatik.hu-berlin.de>
%% @doc    replica update module 
%%         Replica sets will be synchronized in two steps.
%%          I) reconciliation - find set differences  (rep_upd_recon.erl)
%%         II) resolution - resolve found differences (rep_upd_resolve.erl)
%% @end
%% @version $Id$

-module(rep_upd).

-behaviour(gen_component).

-include("record_helpers.hrl").
-include("scalaris.hrl").

-export([start_link/1, init/1, on/2, check_config/0]).

-ifdef(with_export_type_support).
-export_type([db_chunk/0]).
-endif.

-define(TRACE(X,Y), io:format("~w [~p] " ++ X ++ "~n", [?MODULE, self()] ++ Y)).
%-define(TRACE(X,Y), ok).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% constants
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
-define(TRIGGER_NAME, rep_update_trigger).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% type definitions
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

-type db_chunk() :: {intervals:interval(), ?DB:db_as_list()}.

-record(rep_upd_state,
        {
         trigger_state  = ?required(rep_upd_state, trigger_state)   :: trigger:state(),
         sync_round     = 0.0                                       :: float(),
         open_recon     = 0                                         :: non_neg_integer(),
         open_resolve   = 0                                         :: non_neg_integer()
         }).
-type state() :: #rep_upd_state{}.

-type message() ::
    {?TRIGGER_NAME} |
    {request_recon, SenderRUPid::comm:mypid(), Round::float(), SyncMaster::boolean(), rep_upd_recon:recon_stage(), 
        rep_upd_recon:recon_method(), rep_upd_recon:recon_struct()} |
    {request_resolve, Round::float(), rep_upd_resolve:ru_resolve_method(), 
        rep_upd_resolve:ru_resolve_struct(), 
        rep_upd_resolve:ru_resolve_answer(), rep_upd_resolve:ru_resolve_answer()} |
    {web_debug_info, Requestor::comm:erl_local_pid()} |
    {recon_progress_report, Sender::comm:erl_local_pid(), Round::float(), 
        Master::boolean(), Stats::rep_upd_recon:ru_recon_stats()} |
    {resolve_progress_report, Sender::comm:erl_local_pid(), Round::float(), 
        Stats::rep_upd_resolve:ru_resolve_stats()}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Message handling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Message handler when trigger triggers (INITIATE SYNC BY TRIGGER)
-spec on(message(), state()) -> state().
on({?TRIGGER_NAME}, State = #rep_upd_state{ sync_round = Round,
                                            open_recon = OpenRecon }) ->
    {ok, Pid} = rep_upd_recon:start(Round, undefined),
    RStage = case get_recon_method() of
                 bloom -> build_struct;
                 merkle_tree -> req_shared_interval;        
                 art -> req_shared_interval
             end,
    comm:send_local(Pid, {start_recon, get_recon_method(), RStage, {}, true}),
    NewTriggerState = trigger:next(State#rep_upd_state.trigger_state),
    %?TRACE("Trigger NEXT", []),
    State#rep_upd_state{ trigger_state = NewTriggerState, 
                         sync_round = Round + 1,
                         open_recon = OpenRecon + 1 };

%% @doc receive sync request and spawn a new process which executes a sync protocol
on({request_recon, Sender, Round, Master, ReconStage, ReconMethod, ReconStruct}, 
   State = #rep_upd_state{ open_recon = OpenRecon }) ->
    monitor:proc_set_value(?MODULE, "Recv-Sync-Req-Count",
                           fun(Old) -> rrd:add_now(1, Old) end),
    {ok, Pid} = rep_upd_recon:start(Round, Sender),
    comm:send_local(Pid, {start_recon, ReconMethod, ReconStage, ReconStruct, Master}),
    State#rep_upd_state{ open_recon = OpenRecon + 1 };

on({request_resolve, Round, RMethod, RStruct, Feedback, SendStats}, 
   State = #rep_upd_state{ open_resolve = OpenResolve }) ->
    _ = rep_upd_resolve:start(Round, RMethod, RStruct, Feedback, SendStats),
    State#rep_upd_state{ open_resolve = OpenResolve + 1 };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Monitor Reporting
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({recon_progress_report, Sender, Round, Master, Stats}, State) ->
    %monitor:proc_set_value(?MODULE, "Progress",
    %                       fun(Old) -> rrd:add_now(Value, Old) end),
    Master andalso
        ?TRACE("SYNC FINISHED - Round=~p - Sender=~p - Master=~p~nStats=~p", 
               [Round, Sender, Master, rep_upd_recon:print_recon_stats(Stats)]),
    State#rep_upd_state{ open_recon = State#rep_upd_state.open_recon - 1 };

on({resolve_progress_report, Sender, Round, Stats}, State) ->
    %monitor:proc_set_value(?MODULE, "Progress",
    %                       fun(Old) -> rrd:add_now(Value, Old) end),
    ?TRACE("SYNC FINISHED - Round=~p - Sender=~p ~nStats=~p~nOpenRecon=~p ; OpenResolve=~p", 
           [Round, Sender, rep_upd_resolve:print_resolve_stats(Stats),
            State#rep_upd_state.open_recon, State#rep_upd_state.open_resolve]),    
    State#rep_upd_state{ open_resolve = State#rep_upd_state.open_resolve - 1 };

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Web Debug Message handling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
on({web_debug_info, Requestor}, State) ->
    #rep_upd_state{ sync_round = Round, 
                    open_recon = OpenRecon, 
                    open_resolve = OpenResol } = State,
    KeyValueList =
        [{"Recon Method:", get_recon_method()},
         {"Resolve Method:", get_resolve_method()},
         {"Bloom Module:", ?REP_BLOOM},
         {"Sync Round:", Round},
         {"Open Recon Jobs:", OpenRecon},
         {"Open Resolve Jobs:", OpenResol}
        ],
    comm:send_local(Requestor, {web_debug_info_reply, KeyValueList}),
    State.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Startup
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Starts the replica update process, 
%%      registers it with the process dictionary
%%      and returns its pid for use by a supervisor.
-spec start_link(pid_groups:groupname()) -> {ok, pid()}.
start_link(DHTNodeGroup) ->
    Trigger = get_update_trigger(),
    gen_component:start_link(?MODULE, Trigger,
                             [{pid_groups_join_as, DHTNodeGroup, ?MODULE}]).

%% @doc Initialises the module and starts the trigger
-spec init(module()) -> state().
init(Trigger) ->	
    TriggerState = trigger:init(Trigger, fun get_update_interval/0, ?TRIGGER_NAME),
    monitor:proc_set_value(?MODULE, "Recv-Sync-Req-Count", rrd:create(60 * 1000000, 3, counter)), % 60s monitoring interval
    monitor:proc_set_value(?MODULE, "Send-Sync-Req", rrd:create(60 * 1000000, 3, event)), % 60s monitoring interval
    monitor:proc_set_value(?MODULE, "Progress", rrd:create(60 * 1000000, 3, event)), % 60s monitoring interval
    #rep_upd_state{trigger_state = trigger:next(TriggerState)}.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
% Config handling
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

%% @doc Checks whether config parameters exist and are valid.
-spec check_config() -> boolean().
check_config() ->
    case config:read(rep_update_activate) of
        true ->
            config:cfg_is_module(rep_update_trigger) andalso
            config:cfg_is_atom(rep_update_recon_method) andalso
            config:cfg_is_atom(rep_update_resolve_method) andalso
            config:cfg_is_integer(rep_update_interval) andalso
            config:cfg_is_greater_than(rep_update_interval, 0);
        _ -> true
    end.

-spec get_resolve_method() -> rep_upd_resolve:ru_resolve_method().
get_resolve_method() ->
    config:read(rep_update_resolve_method).

-spec get_recon_method() -> rep_upd_recon:recon_method().
get_recon_method() -> 
	config:read(rep_update_recon_method).

-spec get_update_trigger() -> Trigger::module().
get_update_trigger() -> 
	config:read(rep_update_trigger).

-spec get_update_interval() -> pos_integer().
get_update_interval() ->
    config:read(rep_update_interval).
