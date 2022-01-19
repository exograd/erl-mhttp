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

-module(mhttp_utils).

-export([suffix/2]).

-spec suffix(binary(), binary()) -> nomatch | binary().
suffix(String0, Suffix0) ->
  String = String0,
  Suffix = Suffix0,
  StringSize = byte_size(String),
  SuffixSize = byte_size(Suffix),
  if
    SuffixSize =< StringSize ->
      PrefixSize = StringSize - SuffixSize,
      case binary:part(String, PrefixSize, SuffixSize) of
        Suffix ->
          binary:part(String, 0, PrefixSize);
        _ ->
          nomatch
      end;
    true ->
      nomatch
  end.
