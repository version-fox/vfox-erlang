%% Copyright 2026 vfox-erlang contributors
%%
%% Licensed under the Apache License, Version 2.0 (the "License");
%% you may not use this file except in compliance with the License.
%% You may obtain a copy of the License at
%%
%%   http://www.apache.org/licenses/LICENSE-2.0
%%
%% Unless required by applicable law or agreed to in writing, software
%% distributed under the License is distributed on an "AS IS" BASIS,
%% WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
%% See the License for the specific language governing permissions and
%% limitations under the License.

-module(hello).
-export([hello_world/0, print_otp_version/0]).

hello_world() -> 
    print_otp_version(),
    io:fwrite("hello, world\n").

print_otp_version() ->
    Version = erlang:system_info(otp_release),
    io:fwrite("You are using Erlang/OTP ~s~n", [Version]).