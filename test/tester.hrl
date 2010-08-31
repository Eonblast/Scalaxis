%  @copyright 2010 Konrad-Zuse-Zentrum fuer Informationstechnik Berlin
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
%%% File    tester.hrl
%%% @author Thorsten Schuett <schuett@zib.de>
%%% @doc    test generator record definitions
%%% @end
%%% Created :  30 April 2010 by Thorsten Schuett <schuett@zib.de>
%%%-------------------------------------------------------------------
%% @version $Id$
-include_lib("../include/scalaris.hrl").

-type(test_any() ::
   % | none()
   % | no_return()
   % | pid()
   % | port()
   % | ref()
       []
     | atom()
   % | binary()
     | float()
   % | Fun
     | integer()
     | 42
     | -1..1
     | list()
     | list(test_any())
   % | improper_list(test_any(), test_any()
   % | maybe_improper_list(test_any(), test_any())
     | tuple()
     | {}
     | {test_any(), test_any(), test_any()}
   % | Union
   % | Userdefined
           ).


-type(type_infos() :: gb_tree()).
-type(builtin_type() ::
      dict
    | gb_tree
    | gb_set
    | module
    | iodata).

-type(type_name() ::
      {'fun', Module :: module(), FunName :: atom(), FunArity :: byte()}
      | {type, Module :: module(), TypeName :: atom()}).

-ifdef(forward_or_recursive_types_are_not_allowed).
-type(record_field_type() ::
     {typed_record_field, atom(), any()}
   | {untyped_record_field, atom()}).

-type(type_spec() ::
      {'fun', any(), any()}
    | {product, [any()]}
    | {tuple, [any()]}
    | {tuple, {typedef, tester, test_any}}
    | {list, any()}
    | {nonempty_list, any()}
    | {range, {integer, integer()}, {integer, integer()}}
    | {union, [any()]}
    | {record, atom(), atom()}
    | nonempty_string
    | integer
    | pos_integer
    | non_neg_integer
    | bool
    | binary
    | iolist
    | node
    | pid
    | port
    | reference
    | none
    | no_return
    | {typedef, module(), atom()}
    | atom
    | float
    | nil
    | {atom, atom()}
    | {integer, integer()}
    | {builtin_type, builtin_type()}
    | {record, list(record_field_type())}
     ).
-else.
-type(record_field_type() ::
     {typed_record_field, atom(), type_spec()}
   | {untyped_record_field, atom()}).

-type(type_spec() ::
      {'fun', type_spec(), type_spec()}
    | {product, [type_spec()]}
    | {tuple, [type_spec()]}
    | {tuple, {typedef, tester, test_any}}
    | {list, type_spec()}
    | {nonempty_list, type_spec()}
    | {range, {integer, integer()}, {integer, integer()}}
    | {union, [type_spec()]}
    | {record, atom(), atom()}
    | nonempty_string
    | integer
    | pos_integer
    | non_neg_integer
    | bool
    | binary
    | iolist
    | node
    | pid
    | port
    | reference
    | none
    | no_return
    | {typedef, module(), atom()}
    | atom
    | float
    | nil
    | {atom, atom()}
    | {integer, integer()}
    | {builtin_type, builtin_type()}
    | {record, list(record_field_type())}
     ).
-endif.

-record(parse_state,  {type_infos :: type_infos(),
                       unknown_types :: gb_set(),
                       atoms :: gb_set(),
                       binaries :: gb_set(),
                       integers :: gb_set(),
                       floats :: gb_set(),
                       strings :: gb_set()
                       }).

