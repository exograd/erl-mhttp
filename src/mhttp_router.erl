%% Copyright (c) 2020-2022 Exograd SAS.
%%
%% Permission to use, copy, modify, and/or distribute this software for any
%% purpose with or without fee is hereby granted, provided that the above
%% copyright notice and this permission notice appear in all copies.
%%
%% THE SOFTWARE IS PROVIDED "AS IS" AND THE AUTHOR DISCLAIMS ALL WARRANTIES
%% WITH REGARD TO THIS SOFTWARE INCLUDING ALL IMPLIED WARRANTIES OF
%% MERCHANTABILITY AND FITNESS. IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY
%% SPECIAL, DIRECT, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
%% WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
%% ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR
%% IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

-module(mhttp_router).

-export([find_route/3]).

-export_type([router/0]).

-type router() :: #{routes := [mhttp:route()]}.

-spec find_route(router(), mhttp:request(), mhttp:handler_context()) ->
        {ok, {mhttp:route(), mhttp:handler_context()}} |
        {error, not_found | term()}.
find_route(#{routes := Routes}, Request, Context) ->
  case do_find_route(Routes, Request) of
    {ok, {Route = {Pattern, RouteHandler}, PathVariables}} ->
      Context2 = update_context_route_id(Context, Pattern),
      case RouteHandler of
        Handler when is_function(Handler) ->
          {ok, {Route, Context2#{path_variables => PathVariables}}};
        {Handler, Options} when is_function(Handler) ->
          Context3 = apply_handler_route_options(Options, Request, Context2),
          {ok, {Route, Context3#{path_variables => PathVariables}}};
        {router, Router2} ->
          find_route(Router2, Request, Context2);
        {router, Router2, Options} ->
          {Request2, Context3} =
            apply_handler_router_options(Options, Request, Context2),
          find_route(Router2, Request2, Context3)
      end;
    {error, not_found} ->
      {error, not_found};
    {error, Reason} ->
      {error, Reason}
  end.

-spec update_context_route_id(mhttp:handler_context(),
                              mhttp_patterns:pattern()) ->
        mhttp:handler_context().
update_context_route_id(Context = #{route_id := RouteId}, Pattern) ->
  PathPattern1 =
    case mhttp_patterns:path_pattern(Pattern) of
      <<"/">> -> <<>>;
      S -> S
    end,
  %% We look for the final wildcard on the original value, to make sure to
  %% detect it if we just added the method suffix.
  case mhttp_utils:suffix(PathPattern1, <<"/...">>) of
    nomatch ->
      PathPattern2 =
        case mhttp_patterns:method(Pattern) of
          {ok, Method} ->
            MethodString = mhttp:method_string(Method),
            <<PathPattern1/binary, $\s, MethodString/binary>>;
          error ->
            PathPattern1
        end,
      Context#{route_id => <<RouteId/binary, PathPattern2/binary>>};
    PathPattern2 ->
      Context#{route_id => <<RouteId/binary, PathPattern2/binary>>}
  end.

-spec do_find_route([mhttp:route()], mhttp:request()) ->
        {ok, {mhttp:route(), mhttp_patterns:path_variables()}} |
        {error, not_found | term()}.
do_find_route([], _Request) ->
  {error, not_found};
do_find_route([Route = {Pattern, _} | Routes], Request) ->
  case mhttp_patterns:match(Pattern, Request) of
    {true, PathVariables} ->
      {ok, {Route, PathVariables}};
    false ->
      do_find_route(Routes, Request);
    {error, Reason} ->
      {error, Reason}
  end.

-spec apply_handler_route_options(mhttp:handler_route_options(),
                                  mhttp:request(), mhttp:handler_context()) ->
        mhttp:handler_context().
apply_handler_route_options(Options, Request, Context) ->
  maps:fold(fun (Name, Value, Acc) ->
                apply_handler_route_option(Name, Value, Request, Acc)
            end, Context, Options).

-spec apply_handler_route_option(Name :: atom(), Value :: term(),
                                 mhttp:request(), mhttp:handler_context()) ->
        mhttp:handler_context().
apply_handler_route_option(disable_request_logging, Value, _, Context) ->
  Context#{disable_request_logging => Value}.

-spec apply_handler_router_options(mhttp:handler_router_options(),
                                   mhttp:request(), mhttp:handler_context()) ->
        {mhttp:request(), mhttp:handler_context()}.
apply_handler_router_options(Options, Request, Context) ->
  maps:fold(fun apply_handler_router_option/3, {Request, Context}, Options).

-spec apply_handler_router_option(Name :: atom(), Value :: term(),
                                  {mhttp:request(), mhttp:handler_context()}) ->
        {mhttp:request(), mhttp:handler_context()}.
apply_handler_router_option(strip_path_prefix, Prefix, {Request, Context}) ->
  Target = mhttp_request:target_uri(Request),
  Target2 = mhttp_uri:strip_path_prefix(Target, Prefix),
  {Request#{target => Target2}, Context}.
