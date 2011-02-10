%  @copyright 2011 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

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

%% @author Nico Kruber <kruber@zib.de>
%% @doc    Test suite for the math_pos module.
%% @end
%% @version $Id$
-module(math_pos_SUITE).
-author('kruber@zib.de').
-vsn('$Id$ ').

-compile(export_all).

-include("unittest.hrl").
-include("scalaris.hrl").

all() ->
    [plus, minus, multiply, divide,
     tester_make_same_length,
     tester_plus_symm, tester_plus_valid,
     tester_minus, tester_minus_valid,
     prop_divide_valid, prop_multiply_valid].

suite() ->
    [
     {timetrap, {seconds, 10}}
    ].

init_per_suite(Config) ->
    unittest_helper:init_per_suite(Config).

end_per_suite(Config) ->
    _ = unittest_helper:end_per_suite(Config),
    ok.

-spec plus(Config::[tuple()]) -> ok.
plus(_Config) ->
    ?equals(math_pos:plus(  [1],   [1], 10),   [2]),
    ?equals(math_pos:plus(  [1],   [2], 10),   [3]),
    ?equals(math_pos:plus(  [1],   [9], 10),   [0]),
    ?equals(math_pos:plus([0,1], [0,9], 10), [1,0]),
    ?equals(math_pos:plus(  [2],   [1], 10),   [3]),
    ?equals(math_pos:plus(  [9],   [1], 10),   [0]),
    ?equals(math_pos:plus([0,9], [0,1], 10), [1,0]).

-spec minus(Config::[tuple()]) -> ok.
minus(_Config) ->
    ?equals(math_pos:minus(  [1],   [1], 10),   [0]),
    ?equals(math_pos:minus(  [1],   [2], 10),   [9]),
    ?equals(math_pos:minus(  [1],   [9], 10),   [2]),
    ?equals(math_pos:minus([0,1], [0,9], 10), [9,2]),
    ?equals(math_pos:minus(  [2],   [1], 10),   [1]),
    ?equals(math_pos:minus(  [9],   [1], 10),   [8]),
    ?equals(math_pos:minus([0,9], [0,1], 10), [0,8]).

-spec multiply(Config::[tuple()]) -> ok.
multiply(_Config) ->
    ?equals(math_pos:multiply(  [1], 2, 10),   [2]),
    ?equals(math_pos:multiply(  [2], 2, 10),   [4]),
    ?equals(math_pos:multiply(  [3], 2, 10),   [6]),
    ?equals(math_pos:multiply(  [4], 2, 10),   [8]),
    ?equals(math_pos:multiply(  [5], 2, 10),   [0]),
    ?equals(math_pos:multiply(  [6], 2, 10),   [2]),
    ?equals(math_pos:multiply(  [7], 2, 10),   [4]),
    ?equals(math_pos:multiply([0,1], 2, 10), [0,2]),
    ?equals(math_pos:multiply([0,2], 2, 10), [0,4]),
    ?equals(math_pos:multiply([0,3], 2, 10), [0,6]),
    ?equals(math_pos:multiply([0,4], 2, 10), [0,8]),
    ?equals(math_pos:multiply([0,5], 2, 10), [1,0]),
    ?equals(math_pos:multiply([0,6], 2, 10), [1,2]),
    ?equals(math_pos:multiply([0,7], 2, 10), [1,4]),
    
    ?equals(math_pos:multiply(  [1], 3, 10),   [3]),
    ?equals(math_pos:multiply(  [2], 3, 10),   [6]),
    ?equals(math_pos:multiply(  [3], 3, 10),   [9]),
    ?equals(math_pos:multiply(  [4], 3, 10),   [2]),
    ?equals(math_pos:multiply(  [5], 3, 10),   [5]),
    ?equals(math_pos:multiply(  [6], 3, 10),   [8]),
    ?equals(math_pos:multiply(  [7], 3, 10),   [1]),
    ?equals(math_pos:multiply([0,1], 3, 10), [0,3]),
    ?equals(math_pos:multiply([0,2], 3, 10), [0,6]),
    ?equals(math_pos:multiply([0,3], 3, 10), [0,9]),
    ?equals(math_pos:multiply([0,4], 3, 10), [1,2]),
    ?equals(math_pos:multiply([0,5], 3, 10), [1,5]),
    ?equals(math_pos:multiply([0,6], 3, 10), [1,8]),
    ?equals(math_pos:multiply([0,7], 3, 10), [2,1]).

-spec divide(Config::[tuple()]) -> ok.
divide(_Config) ->
    ?equals(math_pos:divide(  [1], 2, 10),   [0]),
    ?equals(math_pos:divide(  [2], 2, 10),   [1]),
    ?equals(math_pos:divide(  [3], 2, 10),   [1]),
    ?equals(math_pos:divide(  [4], 2, 10),   [2]),
    ?equals(math_pos:divide([1,0], 2, 10), [0,5]),
    ?equals(math_pos:divide([1,1], 2, 10), [0,5]),
    ?equals(math_pos:divide([1,2], 2, 10), [0,6]),
    ?equals(math_pos:divide([1,3], 2, 10), [0,6]),
    ?equals(math_pos:divide([1,4], 2, 10), [0,7]),
    ?equals(math_pos:divide([2,0], 2, 10), [1,0]),
    ?equals(math_pos:divide([2,1], 2, 10), [1,0]),
    ?equals(math_pos:divide([2,2], 2, 10), [1,1]),
    ?equals(math_pos:divide([2,3], 2, 10), [1,1]),
    ?equals(math_pos:divide([2,4], 2, 10), [1,2]),
    
    ?equals(math_pos:divide(  [1], 3, 10),   [0]),
    ?equals(math_pos:divide(  [2], 3, 10),   [0]),
    ?equals(math_pos:divide(  [3], 3, 10),   [1]),
    ?equals(math_pos:divide(  [4], 3, 10),   [1]),
    ?equals(math_pos:divide([1,0], 3, 10), [0,3]),
    ?equals(math_pos:divide([1,1], 3, 10), [0,3]),
    ?equals(math_pos:divide([1,2], 3, 10), [0,4]),
    ?equals(math_pos:divide([1,3], 3, 10), [0,4]),
    ?equals(math_pos:divide([1,4], 3, 10), [0,4]),
    ?equals(math_pos:divide([2,0], 3, 10), [0,6]),
    ?equals(math_pos:divide([2,1], 3, 10), [0,7]),
    ?equals(math_pos:divide([3,0], 3, 10), [1,0]),
    ?equals(math_pos:divide([3,1], 3, 10), [1,0]),
    ?equals(math_pos:divide([3,2], 3, 10), [1,0]),
    ?equals(math_pos:divide([3,3], 3, 10), [1,1]),
    ?equals(math_pos:divide([3,4], 3, 10), [1,1]),
    ?equals(math_pos:divide([3,5], 3, 10), [1,1]),
    ?equals(math_pos:divide([3,6], 3, 10), [1,2]).

%% make_same_length

-spec prop_make_same_length(A::string(), B::string(), front | back) -> true.
prop_make_same_length(A, B, Pos) ->
    {A1, B1} = math_pos:make_same_length(A, B, Pos),
    ?equals(erlang:length(A1), erlang:length(B1)),
    ?equals(math_pos:remove_zeros(A1, Pos), math_pos:remove_zeros(A, Pos)),
    ?equals(math_pos:remove_zeros(B1, Pos), math_pos:remove_zeros(B, Pos)),
    true.

-spec tester_make_same_length(Config::[tuple()]) -> ok.
tester_make_same_length(_Config) ->
    tester:test(?MODULE, prop_make_same_length, 3, 10000).

%% plus

-spec prop_plus_valid_base(X, X, Pos::front | back, Base::pos_integer()) -> true when is_subtype(X, list(non_neg_integer())).
prop_plus_valid_base(A_, B_, Pos, Base) ->
    {A, B} = math_pos:make_same_length(A_, B_, Pos),
    A_plus_B = math_pos:plus(A, B, Base),
    ?equals(erlang:length(A_plus_B), erlang:length(A)),
    case lists:all(fun(E) -> E >= 0 andalso E < Base end, A_plus_B) of
        true -> true;
        _ -> ?ct_fail("math_pos:plus(A, B, ~B) evaluated to \"~.0p\" and "
                      "contains invalid elements~n",
                      [Base, A_plus_B])
    end.

-spec prop_plus_valid1(A::[0..9], B::[0..9]) -> true.
prop_plus_valid1(A_, B_) -> prop_plus_valid_base(A_, B_, front, 10).

-spec prop_plus_valid2(A::string(), B::string()) -> true.
prop_plus_valid2(A_, B_) -> prop_plus_valid_base(A_, B_, back, 16#10ffff + 1).

-spec prop_plus_valid3(A::nonempty_string(), B::nonempty_string()) -> true.
prop_plus_valid3(A_, B_) ->
    Base = erlang:max(lists:max(A_), lists:max(B_)) + 1,
    prop_plus_valid_base(A_, B_, back, Base).

-spec tester_plus_valid(Config::[tuple()]) -> ok.
tester_plus_valid(_Config) ->
    tester:test(?MODULE, prop_plus_valid1, 2, 10000),
    tester:test(?MODULE, prop_plus_valid2, 2, 10000),
    tester:test(?MODULE, prop_plus_valid3, 2, 10000).

-spec prop_plus_symm_base(X, X, Pos::front | back, Base::pos_integer()) -> true when is_subtype(X, list(non_neg_integer())).
prop_plus_symm_base(A_, B_, Pos, Base) ->
    {A, B} = math_pos:make_same_length(A_, B_, Pos),
    ?equals(math_pos:plus(A, B, Base), math_pos:plus(B, A, Base)),
    true.

-spec prop_plus_symm1(A::[0..9], B::[0..9]) -> true.
prop_plus_symm1(A_, B_) -> prop_plus_symm_base(A_, B_, front, 10).

-spec prop_plus_symm2(A::string(), B::string()) -> true.
prop_plus_symm2(A_, B_) -> prop_plus_symm_base(A_, B_, back, 16#10ffff + 1).

-spec prop_plus_symm3(A::nonempty_string(), B::nonempty_string()) -> true.
prop_plus_symm3(A_, B_) ->
    Base = erlang:max(lists:max(A_), lists:max(B_)) + 1,
    prop_plus_symm_base(A_, B_, back, Base).

-spec tester_plus_symm(Config::[tuple()]) -> ok.
tester_plus_symm(_Config) ->
    tester:test(?MODULE, prop_plus_symm1, 2, 10000),
    tester:test(?MODULE, prop_plus_symm2, 2, 10000),
    tester:test(?MODULE, prop_plus_symm3, 2, 10000).

%% minus

-spec prop_minus_valid_base(X, X, Pos::front | back, Base::pos_integer()) -> true when is_subtype(X, list(non_neg_integer())).
prop_minus_valid_base(A_, B_, Pos, Base) ->
    {A, B} = math_pos:make_same_length(A_, B_, Pos),
    A_minus_B = math_pos:minus(A, B, Base),
    ?equals(erlang:length(A_minus_B), erlang:length(A)),
    case lists:all(fun(E) -> E >= 0 andalso E < Base end, A_minus_B) of
        true -> true;
        _ -> ?ct_fail("math_pos:minus(A, B, ~B) evaluated to \"~.0p\" and "
                      "contains invalid elements~n",
                      [Base, A_minus_B])
    end.

-spec prop_minus_valid1(A::[0..9], B::[0..9]) -> true.
prop_minus_valid1(A_, B_) -> prop_minus_valid_base(A_, B_, front, 10).

-spec prop_minus_valid2(A::string(), B::string()) -> true.
prop_minus_valid2(A_, B_) -> prop_minus_valid_base(A_, B_, back, 16#10ffff + 1).

-spec prop_minus_valid3(A::nonempty_string(), B::nonempty_string()) -> true.
prop_minus_valid3(A_, B_) ->
    Base = erlang:max(lists:max(A_), lists:max(B_)) + 1,
    prop_minus_valid_base(A_, B_, back, Base).

-spec tester_minus_valid(Config::[tuple()]) -> ok.
tester_minus_valid(_Config) ->
    tester:test(?MODULE, prop_minus_valid1, 2, 10000),
    prop_minus_valid2([557056,0,0,0,0,1], [557055,1114111,1114111,1114111,1114111,1114111]),
    tester:test(?MODULE, prop_minus_valid2, 2, 10000),
    tester:test(?MODULE, prop_minus_valid3, 2, 10000).

-spec prop_minus_base(X, X, Pos::front | back, Base::pos_integer()) -> true when is_subtype(X, list(non_neg_integer())).
prop_minus_base(A_, B_, Pos, Base) ->
    {A, B} = math_pos:make_same_length(A_, B_, Pos),
    A_B = math_pos:minus(A, B, Base),
    ?equals(math_pos:plus(A_B, B, Base), A),
    true.

-spec prop_minus1(A::[0..9], B::[0..9]) -> true.
prop_minus1(A_, B_) -> prop_minus_base(A_, B_, front, 10).

-spec prop_minus2(A::string(), B::string()) -> true.
prop_minus2(A_, B_) -> prop_minus_base(A_, B_, back, 16#10ffff + 1).

-spec prop_minus3(A::nonempty_string(), B::nonempty_string()) -> true.
prop_minus3(A_, B_) ->
    Base = erlang:max(lists:max(A_), lists:max(B_)) + 1,
    prop_minus_base(A_, B_, back, Base).

-spec tester_minus(Config::[tuple()]) -> ok.
tester_minus(_Config) ->
    tester:test(?MODULE, prop_minus1, 2, 10000),
    tester:test(?MODULE, prop_minus2, 2, 10000),
    tester:test(?MODULE, prop_minus3, 2, 10000).

%% divide

-spec prop_divide_valid_base(X, Div::pos_integer(), Base::pos_integer()) -> true when is_subtype(X, list(non_neg_integer())).
prop_divide_valid_base(A, Div, Base) ->
    A_div = math_pos:divide(A, Div, Base),
    ?equals(erlang:length(A_div), erlang:length(A)),
    case lists:all(fun(E) -> E >= 0 andalso E < Base end, A_div) of
        true -> true;
        _ -> ?ct_fail("math_pos:divide(A, Div, ~B) evaluated to \"~.0p\" and "
                      "contains invalid elements~n",
                      [Base, A_div])
    end.

-spec prop_divide_valid1(A::[0..9], Div::pos_integer()) -> true.
prop_divide_valid1(A, Div) -> prop_divide_valid_base(A, Div, 10).

-spec prop_divide_valid2(A::string(), Div::pos_integer()) -> true.
prop_divide_valid2(A, Div) -> prop_divide_valid_base(A, Div, 16#10ffff + 1).

-spec prop_divide_valid3(A::nonempty_string(), Div::pos_integer()) -> true.
prop_divide_valid3(A, Div) ->
    Base = lists:max(A) + 1,
    prop_divide_valid_base(A, Div, Base).

-spec prop_divide_valid(Config::[tuple()]) -> ok.
prop_divide_valid(_Config) ->
    tester:test(?MODULE, prop_divide_valid1, 2, 10000),
    tester:test(?MODULE, prop_divide_valid2, 2, 10000),
    tester:test(?MODULE, prop_divide_valid3, 2, 10000).

%% multiply

-spec prop_multiply_valid_base(X, Fac::non_neg_integer(), Base::pos_integer()) -> true when is_subtype(X, list(non_neg_integer())).
prop_multiply_valid_base(A, Fac, Base) ->
    A_prod = math_pos:multiply(A, Fac, Base),
    ?equals(erlang:length(A_prod), erlang:length(A)),
    case lists:all(fun(E) -> E >= 0 andalso E < Base end, A_prod) of
        true -> true;
        _ -> ?ct_fail("math_pos:multiply(A, Div, ~B) evaluated to \"~.0p\" and "
                      "contains invalid elements~n",
                      [Base, A_prod])
    end.

-spec prop_multiply_valid1(A::[0..9], Fac::0..9) -> true.
prop_multiply_valid1(A, Fac) -> prop_multiply_valid_base(A, Fac, 10).

-spec prop_multiply_valid2(A::string(), Fac::0..16#10ffff) -> true.
prop_multiply_valid2(A, Fac) -> prop_multiply_valid_base(A, Fac, 16#10ffff + 1).

-spec prop_multiply_valid3(A::nonempty_string(), Fac::non_neg_integer()) -> true.
prop_multiply_valid3(A, Fac) ->
    A_max = lists:max(A), Base = A_max + 1,
    prop_multiply_valid_base(A, erlang:min(Fac, A_max), Base).

-spec prop_multiply_valid(Config::[tuple()]) -> ok.
prop_multiply_valid(_Config) ->
    tester:test(?MODULE, prop_multiply_valid1, 2, 10000),
    tester:test(?MODULE, prop_multiply_valid2, 2, 10000),
    tester:test(?MODULE, prop_multiply_valid3, 2, 10000).
