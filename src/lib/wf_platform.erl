% Nitrogen Web Framework for Erlang
% Copyright (c) 2008-2009 Rusty Klophaus
% See MIT-LICENSE for licensing information.

-module (wf_platform).
-export ([
	init/2,
	get_platform/0,
	get_request/0,
	get_page_module/0, set_page_module/1,
	get_path_info/0, set_path_info/1,

	get_raw_path/0,
	get_querystring/0,
	get_request_method/0,
	get_request_body/0,
	parse_get_args/0,
	parse_post_args/0,

	get_headers/0,
	get_header/1,
	
	get_cookie/1, set_cookie/2, set_cookie/4,
	clear_redirect/0,
	set_redirect/1,
	set_header/2,
	get_peername/0,
	get_socket/0,
	recv_from_socket/2,
	route/1, request/1,
	set_response_code/1,
	set_content_type/1,
	set_response_body/1,
	build_response/0
]).


%%% INIT PLATFORMS %%%
init(PlatformModule, Request) ->
	wf:put(wf_platform_module, PlatformModule),
	wf:put(wf_request, Request),
	ok.
	
do(Method) -> do(Method, []).
do(Method, Args) ->
	PlatformModule = wf:get(wf_platform_module),
	erlang:apply(PlatformModule, Method, Args).



%%% GET PLATFORM INFO %%%

get_platform() -> do(get_platform).
get_request() -> wf:get(wf_request).
get_request_body() -> do(get_request_body).
get_page_module() -> wf:get(wf_page_module).
set_page_module(Module) -> wf:put(wf_page_module, Module).
get_path_info() -> wf:get(wf_path_info).
set_path_info(PathInfo) -> wf:put(wf_path_info, PathInfo).

get_raw_path() -> do(get_raw_path).
get_querystring() -> do(get_querystring).


%%% METHOD AND ARGS %%%

get_request_method() -> do(get_request_method).
parse_get_args() -> do(parse_get_args).
parse_post_args() -> do(parse_post_args).

get_headers() -> do(get_headers, []).
get_header(Header) -> do(get_header, [wf:to_atom(Header)]).
    
%%% COOKIES %%%
	
get_cookie(Key) ->
	Key1 = wf:to_list(Key),
	Value = do(get_cookie, [Key1]),
	case Value of
		[] -> undefined;
		_ -> Value
	end.

set_cookie(Key, Value) -> 
	Timeout = nitrogen:get_session_timeout(),
	set_cookie(Key, Value, "/", Timeout).
	
set_cookie(Key, Value, Path, MinutesToLive) ->
	Header = create_cookie(Key, Value, Path, MinutesToLive),
	wf:put(wf_headers, [Header|wf:get(wf_headers)]),
	ok.
	
create_cookie(Key, Value, Path, MinutesToLive) ->
	Key1 = wf:to_list(Key),
	Value1 = wf:to_list(Value),
	do(create_cookie, [Key1, Value1, Path, MinutesToLive]).
	
	

%%% HEADERS %%%

set_header(Key, Value) ->
	Key1 = wf:to_list(Key),
	Value1 = wf:to_list(Value),
	Header = do(create_header, [Key1, Value1]),
	wf:put(wf_headers, [Header|wf:get(wf_headers)]),
	ok.
	

%%% SOCKETS %%%
get_socket() -> do(get_socket).
get_peername() -> inet:peername(get_socket).
recv_from_socket(Length, Timeout) -> do(recv_from_socket, [Length, Timeout]).


%%% ROUTE AND REQUEST %%%

route(Path) ->
	HooksModule = nitrogen:get_hooks_module(),
	case erlang:function_exported(HooksModule, route, 1) of
		true -> 
			case HooksModule:route(Path) of
				undefined -> nitrogen:route(Path);
				{Module, PathInfo} -> {Module, PathInfo};
				Module -> {Module, ""}
			end;
		false -> nitrogen:route(Path)
	end.
	
request(Module) ->
	% Run the pre-request function, check if we
	% should continue.
	HooksModule = nitrogen:get_hooks_module(),
	case erlang:function_exported(HooksModule, request, 1) of
		true -> HooksModule:request(Module);
		false -> nitrogen:request(Module)
	end.
	
%%% RESPONSE %%%

clear_redirect() -> set_redirect(undefined).
set_redirect(Url) -> wf:put(wf_redirect, Url).
set_response_code(Code) -> wf:put(wf_response_code, Code).
set_content_type(ContentType) -> wf:put(wf_content_type, ContentType).

set_response_body(Body) -> wf:put(wf_response_body, Body).
	
build_response() -> 
	% Handle any redirects...
	handle_redirects(),
	
	% Build platform specific response...
	do(build_response).
	
%%% REDIRECTS %%%
	
handle_redirects() ->
	case wf:get(wf_redirect) of
		undefined -> ignore;
		Url -> 
			Redirect = build_redirect(Url),
			set_response_body(Redirect)
	end.

build_redirect(Url) ->
	Url1 = wf:to_list(Url),
	case get_request_method() of
		'GET' -> build_get_redirect(Url1);
		'POST' -> build_post_redirect(Url1)
	end.

build_get_redirect(Url) -> wf:f("<meta http-equiv='refresh' content='0;url=~s' />", [Url]).
build_post_redirect(Url) -> wf:f("document.location.href=\"~s\";", [wf_utils:js_escape(Url)]).
