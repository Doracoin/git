#!/bin/sh

test_description='compare (unbuilt) Documentation/*.txt to -h output

Run this with --debug to see a summary of where we still fail to make
the two versions consistent with one another.'

. ./test-lib.sh

test_expect_success 'setup: list of builtins' '
	git --list-cmds=builtins >builtins
'

test_expect_success 'setup: list of txt v.s. help' '
	cat >list <<-\EOF
	add
	am
	apply
	archive
	bisect
	blame
	branch
	check-ref-format
	checkout
	checkout-index
	clone
	column
	config
	credential
	credential-cache
	credential-store
	fast-export
	fast-import
	fetch-pack
	fmt-merge-msg
	for-each-ref
	format-patch
	fsck-objects
	fsmonitor--daemon
	gc
	grep
	index-pack
	init-db
	log
	ls-files
	ls-tree
	mailinfo
	mailsplit
	maintenance
	merge
	merge-file
	merge-index
	merge-one-file
	multi-pack-index
	name-rev
	notes
	pack-objects
	push
	range-diff
	rebase
	remote
	remote-ext
	remote-fd
	repack
	reset
	restore
	rev-parse
	show
	stage
	switch
	update-index
	update-ref
	whatchanged
	EOF
'

test_expect_success 'setup: list of txt v.s. help is sorted' '
	sort -u list >list.sorted &&
	if ! test_cmp list list.sorted
	then
		BUG "please keep the command list sorted"
	fi
'

builtin_to_synopsis () {
	builtin="$1" &&
	test_when_finished "rm -f out" &&
	test_expect_code 129 git $builtin -h >out 2>&1 &&
	sed -n \
		-e '1,/^$/ {
			/^$/d;
			s/^usage: //;
			s/^ *or: //;
			p
		}' <out
}

builtin_to_txt () {
	echo "$GIT_BUILD_DIR/Documentation/git-$1.txt"
}

txt_synopsis () {
	sed -n \
		-e '/^\[verse\]$/,/^$/ {
			/^$/d;
			/^\[verse\]$/d;
			s/{litdd}/--/g;

			s/'\''\(git[ a-z-]*\)'\''/\1/g;
			p;
		}' \
		<"$1"
}

HT="	"
align_after_nl () {
	builtin="$1" &&
	len=$(printf "git %s " "$builtin" | wc -c) &&
	pad=$(printf "%${len}s" "") &&

	sed "s/^[ $HT][ $HT]*/$pad/"
}

test_debug '>failing'
while read builtin
do
	txt="$(builtin_to_txt "$builtin")" &&
	preq="$(echo BUILTIN_TXT_$builtin | tr '[:lower:]-' '[:upper:]_')" &&

	if test -f "$txt"
	then
		test_set_prereq "$preq"
	fi &&

	result=
	if grep -q "^$builtin$" list
	then
		result=failure
	else
		result=success
	fi &&

	test_expect_$result "$preq" "$builtin -h output and SYNOPSIS agree" '
		txt_synopsis "$txt" >txt.raw &&
		if test "$builtin" = "merge-tree"
		then
			sed -e '\''s/ (deprecated)$//g'\'' <txt.raw >txt.raw.new &&
			mv txt.raw.new txt.raw
		fi &&
		builtin_to_synopsis "$builtin" >help.raw &&

		# The *.txt and -h use different spacing for the
		# alignment of continued usage output, normalize it.
		align_after_nl "$builtin" <txt.raw >txt &&
		align_after_nl "$builtin" <help.raw >help &&
		test_cmp txt help
	'

	if test_have_prereq "$preq" && test -e txt && test -e help
	then
		test_debug '
			if test_cmp txt help >cmp 2>/dev/null
			then
				echo "=== DONE: $builtin ==="
			else
				echo "=== TODO: $builtin ===" &&
				cat cmp
			fi >>failing
		'

		# Not in test_expect_success in case --run is being
		# used with --debug
		rm -f txt help tmp 2>/dev/null
	fi
done <builtins

test_debug 'say "$(cat failing)"'

test_done
