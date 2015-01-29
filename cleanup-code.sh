#!/bin/bash
set -e

declare -a args

while [[ $# > 1 ]]; do
	key="$1"
	value="$2"
	if [[ $key == --+([[:alpha:]])-file ]]; then
		key="${key%-file}"
		value=$(< "$value" sed 's/^[[:space:]]*//; s/[[:space:]]*$//; /^$/d; s/^.*$/(&)/;' \
				| paste -d'|' -s)
	fi

	case $key in
	--functions)
		regexp=$'(?xs)
			(?<value> \\b('"$value"$')\\b ){0}

			^\\n?
			(?<comment> ^ \s* ( (?> /\* .*? \*/ )
			  | (?> // (?!\s*\#) ( (?! ; \s*$) \N )*? \\n ) ) )*?
			^ ((?! /\* | \*/ )\N)*?

			( /\* ((?! /\* | \*/ ).)*? (?<code>
				(\\b(static|void|int|struct)\\b\N*\\n?\N*)?
			    (?&value)

			    ( (?<lex> (?> (?&comment) | "\N*?" | \'\N*?\' ) ) | (?! /\* | \*/ )[^{};] )*+
			    ( ;
			      | (?<block> {
			          (?> (?&lex) | [^{}] | (?&block) )*
			        } ) ) )+? ((?! /\* | \*/ ).)*? \*/

			  |  ((?! /\* | \*/ )\N)*? (?&code) ((?! /\* | \*/ )\N)*? )+'
	;;
	--directives)
		regexp=$'(?xs)
			(?<value> \\b('"$value"$')\\b ){0}
			(?<ignore>
			    (?> \s* | /\* .*? \*/ | // \N*? \\n )*+ ){0}
			(?<lex> (?&ignore)
			  | (?> "(\\[\\"]|\N)*?" | \'(\\[\\\']|\N)*?\' )*+ ){0}
			(?<block> (?&ignore)
			    \#\s*if(n?def)?\\b
			        ( (?&lex) | (?&block) | . )*?
			    (\#\s*endif\\b|\Z)){0}

			(?<match>
			    (?<comment> ^ ((?!\\n)\s)* ( (?> /\* .*? \*/ \\n{0,2} )
			      | (?> // \N*? \\n ) ) )??
			    (?> \#(?&ignore)\\b (define|undef|(?<include>include)) \\b \N*? (?&value)
			    	(?(<include>)((?<=\.inc)|\.inc)\N*\\n\s*,)?
			      | \#(?&ignore)\\b if(n?def)? \\b \N*? (?&value)
			            ( (?&lex) | (?&block) | . )*?
			        (\#(?&ignore)\\b endif \\b|\Z) ) ){0}

			(?(?= ^\\n ((?&match)\N*? \\n)+? (\\n|\Z) ) ^\\n)
			(?&match)'
	;;
	*)
		>&2 echo "Usage: $0 [[--functions|--directives][-file] regex-or-file]..."
		exit 1
	;;
	esac

	args+=(-e "$regexp")
	shift 2
done

pcregrep -Mv "${args[@]}" || true
# pcregrep --color=always -C2 -M "${args[@]}"
