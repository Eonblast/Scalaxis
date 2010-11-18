% @copyright 2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin

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
%% @doc    Unit tests for src/dht_node_move.erl (slide and jump operations).
%% @end
%% TODO: add more detailed tests that tackle certain parts of the protocol itself
%% @version $Id$
-module(dht_node_move_SUITE).
-author('kruber@zib.de').
-vsn('$Id$').

-compile(export_all).

-include("unittest.hrl").
-include("scalaris.hrl").

all() ->
    [
     symm4_slide_succ1_load, symm4_slide_succ2_load,
     symm4_slide_pred1_load, symm4_slide_pred2_load,
     symm4_slide_succ1_load_v2, symm4_slide_succ2_load_v2,
     symm4_slide_pred1_load_v2, symm4_slide_pred2_load_v2
    ].

suite() ->
    [
     {timetrap, {seconds, 60}}
    ].

init_per_suite(Config) ->
    unittest_helper:init_per_suite(Config).

end_per_suite(Config) ->
    unittest_helper:end_per_suite(Config),
    ok.

init_per_testcase(_TestCase, Config) ->
    Config.

end_per_testcase(_TestCase, Config) ->
    Config.

%% @doc Sets tighter timeouts for slides
-spec set_move_config_parameters() -> ok.
set_move_config_parameters() ->
    config:write(move_notify_succ_timeout, 100),
    config:write(move_notify_pred_timeout, 100),
    config:write(move_send_data_timeout, 100),
    config:write(move_send_delta_timeout, 100),
    config:write(move_rcv_data_timeout, 100),
    config:write(move_data_ack_timeout, 100).
    

%% @doc Test slide with successor, receiving data from it (using cs_api in the bench server).
symm4_slide_succ1_load(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment(10, 1000) end),
                      symm4_slide1_load_test(1, succ, "slide_succ1", fun succ_id_fun1/2),
                      symm4_slide1_load_test(2, succ, "slide_succ1", fun succ_id_fun1/2),
                      symm4_slide1_load_test(3, succ, "slide_succ1", fun succ_id_fun1/2),
                      symm4_slide1_load_test(4, succ, "slide_succ1", fun succ_id_fun1/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_succ1_load"),
    check_size2_v1(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with successor, sending data to it (using cs_api in the bench server).
symm4_slide_succ2_load(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment(10, 1000) end),
                      symm4_slide2_load_test(1, succ, "slide_succ2", fun succ_id_fun2/2),
                      symm4_slide2_load_test(2, succ, "slide_succ2", fun succ_id_fun2/2),
                      symm4_slide2_load_test(3, succ, "slide_succ2", fun succ_id_fun2/2),
                      symm4_slide2_load_test(4, succ, "slide_succ2", fun succ_id_fun2/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_succ2_load"),
    check_size2_v1(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with successor, receiving data from it (using cs_api_v2 in the bench server).
symm4_slide_succ1_load_v2(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment_v2(10, 1000) end),
                      symm4_slide1_load_test(1, succ, "slide_succ1_v2", fun succ_id_fun1/2),
                      symm4_slide1_load_test(2, succ, "slide_succ1_v2", fun succ_id_fun1/2),
                      symm4_slide1_load_test(3, succ, "slide_succ1_v2", fun succ_id_fun1/2),
                      symm4_slide1_load_test(4, succ, "slide_succ1_v2", fun succ_id_fun1/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_succ1_load_v2"),
    check_size2_v2(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with successor, sending data to it (using cs_api_v2 in the bench server).
symm4_slide_succ2_load_v2(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment_v2(10, 1000) end),
                      symm4_slide2_load_test(1, succ, "slide_succ2_v2", fun succ_id_fun2/2),
                      symm4_slide2_load_test(2, succ, "slide_succ2_v2", fun succ_id_fun2/2),
                      symm4_slide2_load_test(3, succ, "slide_succ2_v2", fun succ_id_fun2/2),
                      symm4_slide2_load_test(4, succ, "slide_succ2_v2", fun succ_id_fun2/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_succ2_load_v2"),
    check_size2_v2(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with predecessor, sending data to it (using cs_api in the bench server).
symm4_slide_pred1_load(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment(10, 1000) end),
                      symm4_slide1_load_test(1, pred, "slide_pred1", fun pred_id_fun1/2),
                      symm4_slide1_load_test(2, pred, "slide_pred1", fun pred_id_fun1/2),
                      symm4_slide1_load_test(3, pred, "slide_pred1", fun pred_id_fun1/2),
                      symm4_slide1_load_test(4, pred, "slide_pred1", fun pred_id_fun1/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_pred1_load"),
    check_size2_v1(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with predecessor, receiving data from it (using cs_api in the bench server).
symm4_slide_pred2_load(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment(10, 1000) end),
                      symm4_slide2_load_test(1, pred, "slide_pred2", fun pred_id_fun2/2),
                      symm4_slide2_load_test(2, pred, "slide_pred2", fun pred_id_fun2/2),
                      symm4_slide2_load_test(3, pred, "slide_pred2", fun pred_id_fun2/2),
                      symm4_slide2_load_test(4, pred, "slide_pred2", fun pred_id_fun2/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_pred2_load"),
    check_size2_v1(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with predecessor, sending data to it (using cs_api_v2 in the bench server).
symm4_slide_pred1_load_v2(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment_v2(10, 1000) end),
                      symm4_slide1_load_test(1, pred, "slide_pred1_v2", fun pred_id_fun1/2),
                      symm4_slide1_load_test(2, pred, "slide_pred1_v2", fun pred_id_fun1/2),
                      symm4_slide1_load_test(3, pred, "slide_pred1_v2", fun pred_id_fun1/2),
                      symm4_slide1_load_test(4, pred, "slide_pred1_v2", fun pred_id_fun1/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_pred1_load_v2"),
    check_size2_v2(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

%% @doc Test slide with predecessor, receiving data from it (using cs_api_v2 in the bench server).
symm4_slide_pred2_load_v2(_Config) ->
    unittest_helper:make_ring_with_ids(?RT:get_replica_keys(?RT:hash_key(0))),
    set_move_config_parameters(),
    timer:sleep(500), % wait a bit for the rm-processes to settle
    stop_time(fun() ->
                      BenchPid = erlang:spawn(fun() -> bench_server:run_increment_v2(10, 1000) end),
                      symm4_slide2_load_test(1, pred, "slide_pred2_v2", fun pred_id_fun2/2),
                      symm4_slide2_load_test(2, pred, "slide_pred2_v2", fun pred_id_fun2/2),
                      symm4_slide2_load_test(3, pred, "slide_pred2_v2", fun pred_id_fun2/2),
                      symm4_slide2_load_test(4, pred, "slide_pred2_v2", fun pred_id_fun2/2),
                      unittest_helper:wait_for_process_to_die(BenchPid)
              end, "symm4_slide_pred2_load_v2"),
    check_size2_v2(40),
%%     ?equals(statistics:get_total_load(statistics:get_ring_details()), 40),
    unittest_helper:stop_ring().

-spec percent_range(IdA::?RT:key(), IdB::?RT:key(), Percent::1..99) -> ?RT:key().
percent_range(IdA, IdB, Percent) ->
    % note: this only works with numeric keys:
    (if
         IdB > IdA  -> IdB - IdA;
         IdB < IdA   -> (?RT:n() - IdA - 1) + IdB
     end * Percent) div 100.

-spec normalize(Id::?RT:key()) -> ?RT:key().
normalize(Id) ->
    case Id >= ?RT:n() of
        true -> Id - ?RT:n();
        _    -> Id
    end.

succ_id_fun1(MyId, SuccId) ->
    normalize(MyId + percent_range(MyId, SuccId, 1)).

succ_id_fun2(MyId, PredId) ->
    normalize(MyId - percent_range(PredId, MyId, 1)).

pred_id_fun1(MyId, PredId) ->
    normalize(PredId + percent_range(PredId, MyId, 1)).

pred_id_fun2(PredId, PredsPredId) ->
    normalize(PredId - percent_range(PredsPredId, PredId, 1)).

-spec symm4_slide1_load_test(NthNode::1..4, PredOrSucc::pred | succ, Tag::any(),
        TargetIdFun::fun((MyId::?RT:key(), OtherId::?RT:key()) -> TargetId::?RT:key())) -> ok.
symm4_slide1_load_test(NthNode, PredOrSucc, Tag, TargetIdFun) ->
    % get a random DHT node and let it slide with its successor/predecessor (50 times)
    DhtNode = lists:nth(NthNode, pid_groups:find_all(dht_node)),
    [begin
         comm:send_local(DhtNode, {get_node_details, comm:this(), [node, PredOrSucc]}),
         receive
             {get_node_details_response, NodeDetails} ->
                 Node = node_details:get(NodeDetails, node),
                 Other = node_details:get(NodeDetails, PredOrSucc),
                 TargetId = TargetIdFun(node:id(Node), node:id(Other)),
                 symm4_slide_load_test_slide(DhtNode, PredOrSucc, TargetId, Tag, NthNode, N, Node, Other);
             Y ->
                 ?ct_fail("slide_~.0p(~B.~B, ~.0p) unexpected message "
                          "(waiting for get_node_details_response): ~.0p",
                          [PredOrSucc, NthNode, N, DhtNode, Y])
         end,
         receive Z ->
                     ?ct_fail("slide_~.0p(~B.~B, ~.0p) unexpected message: ~.0p",
                              [PredOrSucc, NthNode, N, DhtNode, Z])
         after 0 -> ok
         end
     end || N <- lists:seq(1, 50)],
    ok.

% note: calls TargetIdFun(MyId, PredId) for PredOrSucc =:= succ and
%       TargetIdFun(PredId, PredsPredId) for PredOrSucc =:= pred
-spec symm4_slide2_load_test(NthNode::1..4, PredOrSucc::pred | succ, Tag::any(),
        TargetIdFun::fun((MyId_or_PredId::?RT:key(), PredId_or_PredsPredId::?RT:key()) -> TargetId::?RT:key())) -> ok.
symm4_slide2_load_test(NthNode, PredOrSucc, Tag, TargetIdFun) ->
    % get a random DHT node and let it slide with its successor/predecessor (50 times)
    DhtNode = lists:nth(NthNode, pid_groups:find_all(dht_node)),
    [begin
         comm:send_local(DhtNode, {get_node_details, comm:this(), [node, pred, succ]}),
         receive
             {get_node_details_response, NodeDetails} ->
                 Node = node_details:get(NodeDetails, node),
                 Other = node_details:get(NodeDetails, PredOrSucc),
                 Pred = node_details:get(NodeDetails, pred),
                 TargetId =
                     case PredOrSucc of
                         succ -> TargetIdFun(node:id(Node), node:id(Pred));
                         pred ->
                             comm:send(node:pidX(Pred), {get_node_details, comm:this(), [pred]}),
                             receive
                                 {get_node_details_response, NodeDetails2} ->
                                     PredsPred = node_details:get(NodeDetails2, pred),
                                     TargetIdFun(node:id(Pred), node:id(PredsPred));
                                 X ->
                                     ?ct_fail("slide_~.0p(~B.~B, ~.0p) unexpected message "
                                                  "(waiting for get_node_details_response): ~.0p",
                                                  [PredOrSucc, NthNode, N, DhtNode, X])
                             end
                     end,
                 symm4_slide_load_test_slide(DhtNode, PredOrSucc, TargetId, Tag, NthNode, N, Node, Other);
             Y ->
                 ?ct_fail("slide_~.0p(~B.~B, ~.0p) unexpected message "
                          "(waiting for get_node_details_response): ~.0p",
                          [PredOrSucc, NthNode, N, DhtNode, Y])
         end,
         receive Z ->
                     ?ct_fail("slide_~.0p(~B.~B, ~.0p) unexpected message: ~.0p",
                              [PredOrSucc, NthNode, N, DhtNode, Z])
         after 0 -> ok
         end
     end || N <- lists:seq(1, 50)],
    ok.

-spec symm4_slide_load_test_slide(DhtNode::pid(), PredOrSucc::pred | succ,
        TargetId::?RT:key(), Tag::any(), NthNode::1..4, N::pos_integer(),
        Node::node:node_type(), Other::node:node_type()) -> ok.
symm4_slide_load_test_slide(DhtNode, PredOrSucc, TargetId, Tag, NthNode, N, Node, Other) ->
    comm:send_local(DhtNode, {move, start_slide, PredOrSucc, TargetId, Tag, self()}),
    receive
        {move, result, Tag, ok} ->
%%             ct:pal("~p.~p ~.0p -> ~.0p", [NthNode, N, node:id(Node), TargetId]),
            ok;
        {move, result, Tag, Result} ->
            case lists:member(Result, [ongoing_slide, wrong_pred_succ_node, notify_succ_timeout, notify_pred_timeout]) of
                true ->
                    ct:pal("slide_~.0p(~B.~B, ~.0p, ~.0p, ~.0p) result: ~.0p~nretrying...",
                           [PredOrSucc, NthNode, N, Node, Other, TargetId, Result]),
                    timer:sleep(100), % wait a bit before trying again
                    symm4_slide_load_test_slide(DhtNode, PredOrSucc, TargetId, Tag, NthNode, N, Node, Other);
                _ ->
                    ?ct_fail("slide_~.0p(~B.~B, ~.0p, ~.0p, ~.0p) result: ~.0p",
                             [PredOrSucc, NthNode, N, Node, Other, TargetId, Result])
            end;
        X ->
            ?ct_fail("slide_~.0p(~B.~B, ~.0p, ~.0p, ~.0p) unexpected message: ~.0p",
                     [PredOrSucc, NthNode, N, Node, Other, TargetId, X])
    end.

-spec check_size2_v1(ExpSize::pos_integer()) -> ok.
check_size2_v1(ExpSize) ->
    Ring = statistics:get_ring_details(),
    Load = statistics:get_total_load(Ring),
    % note: cs_api (v1) may leave old data items on nodes not responsible for them anymore, tolerate it here:
    case Load =/= ExpSize of
        true ->
            DHTNodes = pid_groups:find_all(dht_node),
            DataAll = [begin
                           comm:send_local(DhtNode,
                                           {bulkowner_deliver, intervals:all(),
                                            {bulk_read_entry, comm:this()}}),
                           receive
                               {bulk_read_entry_response, _Range1, D} -> D
                           end
                       end || DhtNode <- DHTNodes],
            Data = lists:flatten(DataAll),
            ct:pal("~.0p", [Data]),
            ?equals_pattern(Load, L when L >= ExpSize);
        false -> ok
    end.

-spec check_size2_v2(ExpSize::pos_integer()) -> ok.
check_size2_v2(ExpSize) ->
    Ring = statistics:get_ring_details(),
    Load = statistics:get_total_load(Ring),
    case Load =/= ExpSize of
        true ->
            DHTNodes = pid_groups:find_all(dht_node),
            DataAll = [begin
                           comm:send_local(DhtNode,
                                           {bulkowner_deliver, intervals:all(),
                                            {bulk_read_entry, comm:this()}}),
                           receive
                               {bulk_read_entry_response, _Range1, D} -> D
                           end
                       end || DhtNode <- DHTNodes],
            Data = lists:flatten(DataAll),
            ct:pal("~.0p", [Data]),
            ?equals(Load, ExpSize);
        false -> ok
    end.

-spec stop_time(F::fun(() -> any()), Tag::string()) -> ok.
stop_time(F, Tag) ->
    Start = erlang:now(),
    F(),
    Stop = erlang:now(),
    ElapsedTime = timer:now_diff(Stop, Start) / 1000000.0,
    Frequency = 1 / ElapsedTime,
    ct:pal("~p took ~ps: ~p1/s",
           [Tag, ElapsedTime, Frequency]),
    ok.

-spec check_size(Size::pos_integer()) -> ok.
check_size(Size) ->
    unittest_helper:check_ring_size(Size),
    unittest_helper:wait_for_stable_ring(),
    unittest_helper:check_ring_size(Size).