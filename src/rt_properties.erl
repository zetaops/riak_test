%% -------------------------------------------------------------------
%%
%% Copyright (c) 2013 Basho Technologies, Inc.
%%
%% This file is provided to you under the Apache License,
%% Version 2.0 (the "License"); you may not use this file
%% except in compliance with the License.  You may obtain
%% a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing,
%% software distributed under the License is distributed on an
%% "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
%% KIND, either express or implied.  See the License for the
%% specific language governing permissions and limitations
%% under the License.
%%
%% -------------------------------------------------------------------

%% @doc Implements a set of functions for accessing and manipulating
%% an `rt_properties' record.-module(rt_properties).

-module(rt_properties).

-include("rt.hrl").
-include_lib("eunit/include/eunit.hrl").

-record(rt_properties_v1, {
          nodes :: [node()],
          node_count=6 :: non_neg_integer(),
          metadata=[] :: proplists:proplist(),
          properties=[] :: proplists:proplist(),
          rolling_upgrade=false :: boolean(),
          start_version=current :: atom(),
          upgrade_version=current :: atom(),
          wait_for_transfers=false :: boolean(),
          valid_backends=all :: all | [atom()],
          make_cluster=true :: boolean(),
          config=default_config() :: term()
         }).
-type properties() :: #rt_properties_v1{}.

-export_type([properties/0]).

-define(RT_PROPERTIES, #rt_properties_v1).
-define(RECORD_FIELDS, record_info(fields, rt_properties_v1)).

-export([new/0,
         new/1,
         get/2,
         set/2,
         set/3,
         default_config/0]).

%% @doc Create a new properties record with all fields initialized to
%% the default values.
-spec new() -> properties().
new() ->
    ?RT_PROPERTIES{}.

%% @doc Create a new properties record with the fields initialized to
%% non-default value.  Each field to be initialized should be
%% specified as an entry in a property list (<i>i.e.</i> a list of
%% pairs). Invalid property fields are ignored by this function.
-spec new(proplists:proplist()) -> properties().
new(PropertyDefaults) ->
    {Properties, _}  =
        lists:foldl(fun set_property/2, {?RT_PROPERTIES{}, []}, PropertyDefaults),
    Properties.

%% @doc Get the value of a property from a properties record. An error
%% is returned if `Properties' is not a valid `rt_properties' record
%% or if the property requested is not a valid property.
-spec get(atom(), properties()) -> term() | {error, atom()}.
get(Property, Properties) ->
    get(Property, Properties, validate_request(Property, Properties)).

%% @doc Set the value for a property in a properties record. An error
%% is returned if `Properties' is not a valid `rt_properties' record
%% or if any of the properties to be set are not a valid property. In
%% the case that invalid properties are specified the error returned
%% contains a list of erroneous properties.
-spec set([{atom(), term()}], properties()) -> {ok, properties()} | {error, atom()}.
set(PropertyList, Properties) when is_list(PropertyList) ->
    set_properties(PropertyList, Properties, validate_record(Properties)).

%% @doc Set the value for a property in a properties record. An error
%% is returned if `Properties' is not a valid `rt_properties' record
%% or if the property to be set is not a valid property.
-spec set(atom(), term(), properties()) -> {ok, properties()} | {error, atom()}.
set(Property, Value, Properties) ->
    set_property(Property, Value, Properties, validate_request(Property, Properties)).


-spec get(atom(), properties(), ok | {error, atom()}) ->
                 term() | {error, atom()}.
get(Property, Properties, ok) ->
    element(field_index(Property), Properties);
get(_Property, _Properties, {error, _}=Error) ->
    Error.

%% This function is used by `new/1' to set properties at record
%% creation time and by `set/2' to set multiple properties at once.
%% Node properties record validation is done by this function. It is
%% strictly used as a fold function which is the reason for the odd
%% structure of the input parameters.  It accumulates any invalid
%% properties that are encountered and the caller may use that
%% information or ignore it.
-spec set_property({atom(), term()}, {properties(), [atom()]}) ->
                          {properties(), [atom()]}.
set_property({Property, Value}, {Properties, Invalid}) ->
    case is_valid_property(Property) of
        true ->
            {setelement(field_index(Property), Properties, Value), Invalid};
        false ->
            {Properties, [Property | Invalid]}
    end.

-spec set_property(atom(), term(), properties(), ok | {error, atom()}) ->
                 {ok, properties()} | {error, atom()}.
set_property(Property, Value, Properties, ok) ->
    {ok, setelement(field_index(Property), Properties, Value)};
set_property(_Property, _Value, _Properties, {error, _}=Error) ->
            Error.

-spec set_properties([{atom(), term()}],
                   properties(),
                   ok | {error, {atom(), [atom()]}}) ->
                          {properties(), [atom()]}.
set_properties(PropertyList, Properties, ok) ->
    case lists:foldl(fun set_property/2, {Properties, []}, PropertyList) of
        {UpdProperties, []} ->
            UpdProperties;
        {_, InvalidProperties} ->
            {error, {invalid_properties, InvalidProperties}}
    end;
set_properties(_, _, {error, _}=Error) ->
    Error.

-spec validate_request(atom(), term()) -> ok | {error, atom()}.
validate_request(Property, Properties) ->
    validate_property(Property, validate_record(Properties)).

-spec validate_record(term()) -> ok | {error, invalid_properties}.
validate_record(Record) ->
    case is_valid_record(Record) of
        true ->
            ok;
        false ->
            {error, invalid_properties}
    end.

-spec validate_property(atom(), ok | {error, atom()}) -> ok | {error, invalid_property}.
validate_property(Property, ok) ->
    case is_valid_property(Property) of
        true ->
            ok;
        false ->
            {error, invalid_property}
    end;
validate_property(_Property, {error, _}=Error) ->
    Error.

-spec default_config() -> [term()].
default_config() ->
    [{riak_core, [{handoff_concurrency, 11}]},
     {riak_search, [{enabled, true}]},
     {riak_pipe, [{worker_limit, 200}]}].

-spec is_valid_record(term()) -> boolean().
is_valid_record(Record) ->
    is_record(Record, rt_properties_v1).

-spec is_valid_property(atom()) -> boolean().
is_valid_property(Property) ->
    Fields = ?RECORD_FIELDS,
    lists:member(Property, Fields).

-spec field_index(atom()) -> non_neg_integer().
field_index(nodes) ->
    ?RT_PROPERTIES.nodes;
field_index(node_count) ->
    ?RT_PROPERTIES.node_count;
field_index(metadata) ->
    ?RT_PROPERTIES.metadata;
field_index(properties) ->
    ?RT_PROPERTIES.properties;
field_index(rolling_upgrade) ->
    ?RT_PROPERTIES.rolling_upgrade;
field_index(start_version) ->
    ?RT_PROPERTIES.start_version;
field_index(upgrade_version) ->
    ?RT_PROPERTIES.upgrade_version;
field_index(wait_for_transfers) ->
    ?RT_PROPERTIES.wait_for_transfers;
field_index(valid_backends) ->
    ?RT_PROPERTIES.valid_backends;
field_index(make_cluster) ->
    ?RT_PROPERTIES.make_cluster;
field_index(config) ->
    ?RT_PROPERTIES.config.