%  Copyright 2008 Zuse Institute Berlin
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
%%% File    : bulkowner_SUITE.erl
%%% Author  : Thorsten Schuett <schuett@zib.de>
%%% Description : Unit tests for src/bulkowner.erl
%%%
%%% Created :  26 Aug 2008 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
-module(bulkowner_SUITE).

-author('schuett@zib.de').
-vsn('$Id$').

-compile(export_all).

-include("unittest.hrl").
-include("scalaris.hrl").

all() ->
    [count].

suite() ->
    [
     {timetrap, {seconds, 10}}
    ].

init_per_suite(Config) ->
    Config2 = unittest_helper:init_per_suite(Config),
    {priv_dir, PrivDir} = lists:keyfind(priv_dir, 1, Config2),
    unittest_helper:make_ring(4, [{config, [{log_path, PrivDir}]}]),
    Config2.

end_per_suite(Config) ->
    _ = unittest_helper:end_per_suite(Config),
    ok.

count(_Config) ->
    ?equals(transaction_api:single_write("i", 2), commit),
    ?equals(transaction_api:single_write("j", 3), commit),
    ?equals(transaction_api:single_write("k", 5), commit),
    ?equals(transaction_api:single_write("l", 7), commit),
    bulkowner:issue_bulk_owner(intervals:all(), {bulk_read_entry, comm:this()}),
    ?equals(collect(0), 68),
    ok.

collect(Sum) ->
    if
	Sum < 68 ->
%%         ct:pal("sum: ~p ~p~n", [Sum, Sum]),
	    receive
            {bulk_read_entry_response, _NowDone, Data} ->
                collect(Sum + reduce(Data))
        end;
	Sum == 68 ->
	    receive
            {bulk_read_entry_response, _NowDone, Data} ->
                Sum + reduce(Data)
	    after 1000 ->
		    Sum
	    end;
	Sum > 68 ->
	    ct:pal("sum: ~p ~p~n", [Sum, Sum]),
	    Sum
    end.

-spec reduce(?DB:db_as_list()) -> integer().
reduce(Entries) ->
    lists:foldl(fun(E, Acc) -> db_entry:get_value(E) + Acc end, 0, Entries).
