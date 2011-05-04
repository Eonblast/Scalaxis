% @copyright 2008-2011 Zuse Institute Berlin

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

%%% @author Thorsten Schuett <schuett@zib.de>
%%% @doc    Unit tests for src/util.erl.
%%% @end
%% @version $Id$
-module(util_SUITE).
-author('schuett@zib.de').
-vsn('$Id$').

-compile(export_all).

-include("unittest.hrl").

all() ->
    [min_max, largest_smaller_than, gb_trees_foldl,
     s_repeat_test, s_repeatAndCollect_test, s_repeatAndAccumulate_test,
     p_repeat_test, p_repeatAndCollect_test, p_repeatAndAccumulate_test].

suite() ->
    [
     {timetrap, {seconds, 20}}
    ].

init_per_suite(Config) ->
    unittest_helper:init_per_suite(Config).

end_per_suite(Config) ->
    _ = unittest_helper:end_per_suite(Config),
    ok.

min_max(_Config) ->
    ?equals(util:min(1, 2), 1),
    ?equals(util:min(2, 1), 1),
    ?equals(util:min(1, 1), 1),
    ?equals(util:max(1, 2), 2),
    ?equals(util:max(2, 1), 2),
    ?equals(util:max(1, 1), 1),
    ok.

largest_smaller_than(_Config) ->
    KVs = [{1, 1}, {2, 2}, {4, 4}, {8, 8}, {16, 16}, {32, 32}, {64, 64}],
    Tree = gb_trees:from_orddict(KVs),
    ?equals(util:gb_trees_largest_smaller_than(0, Tree), nil),
    ?equals(util:gb_trees_largest_smaller_than(1, Tree), nil),
    ?equals(util:gb_trees_largest_smaller_than(2, Tree), {value, 1, 1}),
    ?equals(util:gb_trees_largest_smaller_than(3, Tree), {value, 2, 2}),
    ?equals(util:gb_trees_largest_smaller_than(7, Tree), {value, 4, 4}),
    ?equals(util:gb_trees_largest_smaller_than(9, Tree), {value, 8, 8}),
    ?equals(util:gb_trees_largest_smaller_than(31, Tree), {value, 16, 16}),
    ?equals(util:gb_trees_largest_smaller_than(64, Tree), {value, 32, 32}),
    ?equals(util:gb_trees_largest_smaller_than(65, Tree), {value, 64, 64}),
    ?equals(util:gb_trees_largest_smaller_than(1000, Tree), {value, 64, 64}),
    ok.

gb_trees_foldl(_Config) ->
    KVs = [{1, 1}, {2, 2}, {4, 4}, {8, 8}, {16, 16}, {32, 32}, {64, 64}],
    Tree = gb_trees:from_orddict(KVs),
    ?assert(util:gb_trees_foldl(fun (K, K, Acc) ->
                                        Acc + K
                                end,
                                0,
                                Tree) =:= 127).

s_repeat_test(_) ->
    util:s_repeat(fun() -> io:format("#s_repeat#~n") end, [], 5),
    io:format("s_repeat_test successful if #s_repeat# was printed 5 times~n"),
    ok.

s_repeatAndCollect_test(_) ->
    Times = 3,
    Result = util:s_repeatAndCollect(fun(X) -> X * X end, [Times], Times),
    ?equals(Result, [9, 9, 9]),
    ok.
    
s_repeatAndAccumulate_test(_) ->
    Times = 5,
    Result = util:s_repeatAndAccumulate(fun(X) -> X * X end, 
                                        [Times], 
                                        Times,
                                        fun(X, Y) -> X + Y end,
                                        0),
    ?equals(Result, Times*Times*Times),
    Result2 = util:s_repeatAndAccumulate(fun(X) -> X * X end, 
                                        [Times], 
                                        Times,
                                        fun(X, Y) -> X + Y end,
                                        1000),
    ?equals(Result2, 1000 + Times*Times*Times),    
    ok.

p_repeat_test(_) ->
    Times = 5,
    util:p_repeat(fun(Caller) -> 
                              io:format("~w #p_repeat_test# called by ~w", 
                                        [self(), Caller]) 
                      end, 
                      [self()], 
                      Times),
    io:format("p_repeat_test successful if ~B different pids printed #p_repeat#.", [Times]),
    ok.

p_repeatAndCollect_test(_) ->
   Times = 3,
   Result = util:p_repeatAndCollect(fun(X) -> X * X end, [Times], Times),
   ?equals(Result, [9, 9, 9]),
   ok.

p_repeatAndAccumulate_test(_) ->
    Times = 15,
    Result = util:p_repeatAndAccumulate(fun(X) -> 
                                                R = X * X, 
                                                io:format("pid ~w result ~B", [self(), R]), 
                                                R 
                                        end, 
                                        [Times], 
                                        Times,
                                        fun(X, Y) -> X + Y end,
                                        0),     
    ?equals(Result, Times*Times*Times),    
    Result2 = util:p_repeatAndAccumulate(fun(X) -> X * X end, 
                                        [Times], 
                                        Times,
                                        fun(X, Y) -> X + Y end,
                                        1000),     
    ?equals(Result2, 1000 + Times*Times*Times),    
    ok.
