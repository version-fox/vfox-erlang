-module(hello).
-export([hello_world/0, print_otp_version/0]).

hello_world() -> 
    print_otp_version(),
    io:fwrite("hello, world\n").

print_otp_version() ->
    Version = erlang:system_info(otp_release),
    io:fwrite("You are using Erlang/OTP ~s~n", [Version]).