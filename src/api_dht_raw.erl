%% @copyright 2011 Zuse Institute Berlin

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
%% @author Nico Kruber <kruber@zib.de>
%% @author Florian Schintke <schintke@zib.de>
%% @doc API for raw access to DHT based on (already) hashed keys.
%% @version $Id$
-module(api_dht_raw).
-author('schintke@zib.de').
-vsn('$Id$').

-export([range_read/2]).

-export([unreliable_lookup/2,
         unreliable_get_key/1, unreliable_get_key/3]).

-include("scalaris.hrl").

%% userdevguide-begin api_dht_raw:lookup
-spec unreliable_lookup(Key::?RT:key(), Msg::comm:message()) -> ok.
unreliable_lookup(Key, Msg) ->
    comm:send_local(pid_groups:find_a(dht_node),
                    {lookup_aux, Key, 0, Msg}).

-spec unreliable_get_key(Key::?RT:key()) -> ok.
unreliable_get_key(Key) ->
    unreliable_lookup(Key, {get_key, comm:this(), Key}).

-spec unreliable_get_key(CollectorPid::comm:mypid(),
                         ReqId::{rdht_req_id, pos_integer()},
                         Key::?RT:key()) -> ok.
unreliable_get_key(CollectorPid, ReqId, Key) ->
    unreliable_lookup(Key, {get_key, CollectorPid, ReqId, Key}).
%% userdevguide-end api_dht_raw:lookup

%% @doc Read a range of key-value pairs between the given two keys (inclusive).
-spec range_read(intervals:key(), intervals:key())
                -> {ok | timeout, [db_entry:entry()]}.
range_read(From, To) ->
    Interval = case From of
                   To -> intervals:all();
                   _  -> intervals:new('[', From, To, ']')
               end,
    range_read(Interval).

%% @doc Read a range of key-value pairs in the given interval.
-spec range_read(intervals:interval()) -> {ok | timeout, [db_entry:entry()]}.
range_read(Interval) ->
    Id = util:get_global_uid(),
    bulkowner:issue_bulk_owner(Id, Interval,
                               {bulk_read_entry, comm:this()}),
    TimerRef = comm:send_local_after(config:read(range_read_timeout), self(),
                                     {range_read_timeout, Id}),
    range_read_loop(Interval, Id, intervals:empty(), [], TimerRef).

-spec range_read_loop(Interval::intervals:interval(), Id::util:global_uid(), Done::intervals:interval(), Data::[db_entry:entry()], TimerRef::reference()) -> {ok | timeout, [db_entry:entry()]}.
range_read_loop(Interval, Id, Done, Data, TimerRef) ->
    receive
        {range_read_timeout, Id} ->
            {timeout, lists:flatten(Data)};
        {bulkowner_reply, Id, {bulk_read_entry_response, NowDone, NewData}} ->
            Done2 = intervals:union(NowDone, Done),
            case intervals:is_subset(Interval, Done2) of
                false ->
                    range_read_loop(Interval, Id, Done2, [NewData | Data], TimerRef);
                true ->
                    % cancel timeout
                    _ = erlang:cancel_timer(TimerRef),
                    % consume potential timeout message
                    receive
                        {range_read_timeout} -> ok
                    after 0 -> ok
                    end,
                    {ok, lists:flatten(Data, NewData)}
            end
    end.
