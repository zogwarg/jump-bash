#!/usr/bin/env bash
# This file a standalone program jump-bash
# Based on the jump project https://github.com/flavio/jump
#
# Copyright (C) 2010 Flavio Castelli <flavio@castelli.name>
# Copyright (C) 2010 Giuseppe Capizzi <gcapizzi@gmail.com>
# Copyright (C) 2022 Thomas Buick <thomas.buick@gmail.com>
#
# jump-bash is free software; you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 2 of the License, or
# (at your option) any later version.
#
# jump-bash is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with jump-bash; if not, write to the
# Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301, USA.

_j_complete()
{
  local cur prev opts
  COMPREPLY=()
  cur="${COMP_WORDS[COMP_CWORD]}"
  prev="${COMP_WORDS[COMP_CWORD-1]}"
  opts="-a -d -l -p -h"

  if [[ ${prev} == "-d" ]] ; then
    COMPREPLY=($(compgen -W '$(jq -r ".bookmarks | keys[]" ~/.jump_bookmarks.json)'))
    return 0
  fi

  if [[ ${cur:0:1} == "-" ]]; then
    COMPREPLY=($(compgen -W "${opts}" -- ${cur}))
    return 0
  else
    COMPREPLY=($(compgen -W "$(j -c ${cur})" -- ${cur}))
    return 0
  fi
}

j() {
  if [[ ! -f ~/.jump_bookmarks.json ]] || [[ -z "$(jq . ~/.jump_bookmarks.json)" ]] ; then
    jq -n '{"bookmarks":{}}' > ~/.jump_bookmarks.json
  fi

  print_help() {
  cat <<TERM
Usage: jump [options] [BOOKMARK[/some/subpath]]
    -a Saves current directory in BOOKMARK
    -d Deletes BOOKMARK
    -l List all saved bookmarks
    -p Prints the path of the bookmark
    -h Show this message
TERM
  }

  save_bookmark() {
    if [[ -n "$1" ]] && [[ -d "$2" ]] ; then
      cat ~/.jump_bookmarks.json | BOOK="$1" DIR="$2" jq '.bookmarks[env.BOOK] = env.DIR' > ~/.jump_bookmarks.json.tmp
      mv ~/.jump_bookmarks.json.tmp ~/.jump_bookmarks.json
    else
      print_help
      return 1
    fi
  }

  delete_bookmark() {
    if [[ -n "$1" ]] ; then
      cat ~/.jump_bookmarks.json | BOOK="$1" jq 'del(.bookmarks[env.BOOK])' > ~/.jump_bookmarks.json.tmp
      mv ~/.jump_bookmarks.json.tmp ~/.jump_bookmarks.json
    else
      print_help
      return 1
    fi
  }

  list_bookmarks() {
    jq . ~/.jump_bookmarks.json
  }

  print_bookmark() {
    if [[ -n "$1" ]] ; then
      OUT=$(cat <(jq -R . <(echo "$1")) ~/.jump_bookmarks.json | jq -rs '[
        ( .[0] / "/" | [ .[0] , (.[1:] | join("/") )] ) ,
        .[1]
      ] as [ $book, $saved ] |
        $saved.bookmarks?[$book[0]] as $path |
        if $path
          then ( [ ($path / "/" | .[]) , ( $book[1] / "/" | .[] ) ] | join("/") )
          else null
        end
      ')
      if [[ "$OUT" == "null" ]] ; then
        echo "Bookmark not found." >&2
        return 1
      fi
      echo "$OUT"
    else
      print_help
      return 1
    fi
  }

  print_complete() {
    CURR=$(print_bookmark "$1" 2>/dev/null)
    if [[ -n $CURR ]] ; then
      BOOK="$(echo $1 | jq -rR '. / "/" | .[0]')"
      cat <(compgen -d -S / $CURR | jq -R)  <(compgen -d -S / $CURR/ | jq -R) ~/.jump_bookmarks.json | BOOK="$BOOK" jq -rs '
        [ .[:-1] , .[-1].bookmarks[env.BOOK], env.BOOK ] as [$complete, $replace, $book] |
        $complete[] | sub($replace; $book)
      '
    fi
    compgen -S / -W '$(jq -r ".bookmarks | keys[] " ~/.jump_bookmarks.json)' "$1"
  }

  jump_cd() {
    CURR=$(print_bookmark "$1" 2>/dev/null)
    if [[ -n $CURR ]] && [[ -n $1 ]]; then
      cd $CURR
    else
      print_help
      return 1
    fi
  }

  case "$1" in
    -a) save_bookmark "$2" "$PWD"
        ;;
    -d) delete_bookmark "$2"
        ;;
    -l) list_bookmarks
        ;;
    -p) print_bookmark "$2"
        ;;
    -h) print_help
    return 0
        ;;
    -c) print_complete "$2"
        ;;
    *)  jump_cd "$1"
        ;;
  esac
}

complete -o nospace -F _j_complete j
