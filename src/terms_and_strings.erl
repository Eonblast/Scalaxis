%  Copyright 2007-2008 Konrad-Zuse-Zentrum für Informationstechnik Berlin
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
%% @doc Serialization of erlang terms to (printable) strings with 
%% optionally binary encoding of terms.
%% 
%% @author Stefan Plantikow <plantikow@zib.de>
%%
-module(terms_and_strings).
               
-author('plantikow@zib.de').
-vsn('$Id$').
                  
-compile(export_all).

to_binstr(Term) -> to_str(term_to_binary(Term)).

to_str(Term) ->
	lists:flatten([io_lib:write(Term), $.]).
	
from_str(String) ->
	{ok, Tokens, _EndLine} = erl_scan:string(String),
	{ok, Res} = erl_parse:parse_term(Tokens),
	Res.
	
from_binstr(String) ->
	binary_to_term(from_str(String)).		 
	
to_ehtml(String) ->
	{ pre, [], to_str(String) }.		
	
	
bin_as_list(X) when is_binary(X) -> binary_to_list(X);
bin_as_list(X) -> X.

bin_as_term(X) when is_binary(X) -> binary_to_term(X);
bin_as_term(X) -> X.

	
