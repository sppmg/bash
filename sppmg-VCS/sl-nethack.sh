#!/bin/bash
# set -x
# trap read debug
version="2.5.140207"
comment_file="comment.txt"
######## database var ########
declare -A db_backup_file_dir db_game_files
#db_backup_file_dir["nethack"]="${HOME}/prog/nethack"
#db_game_files["nethack"]="/var/games/nethack/save/${{UID}${USER}.gz"
db_backup_file_dir["nethack"]="${HOME}/prog/nethack"
db_game_files["nethack"]="/var/games/nethack/save/${UID}${USER}.gz"
db_backup_file_dir["test"]="/tmp/sppmg/test"
db_game_files["test"]="/home/sppmg/prog/nethack/test.txt"
######## program var ########
game_name="`basename $0 |sed -r 's/^sl-(.*).sh$/\1/'`"
backup_file_dir="${db_backup_file_dir["${game_name}"]}"
game_files="${db_game_files["${game_name}"]}"
trash_dir="${backup_file_dir}/trash"

game_dir=`dirname "${game_files}"`
game_target=`basename "${game_files}"`


get_fid_last(){
	# This function will get last ID and check exist.
	# The input is number save in $fid. Length of fid will <= 10+1. If length != 10+1(count by wc) then search file. 
	# And function will check it.
	local fid_old=$fid
	echo $(echo "$fid" | wc -m )
	case $(echo "$fid" | wc -m ) in	# here don't chenge to " wc -m <<< $fid " , because busybox can't run
		1 )	# For no fid
			fid=$( ls -1r "${backup_file_dir}" | sed -nr '/^([0-9]{10})\.tar\.gz$/ {s/\.tar\.gz//p;q}' )
			;;
		11 )	# Do nothing for correct length
			;;
		* )	# less then 8 char , arg only pass 1 to 8 number to here . (1 to 9 of wc output)
			fid=$(ls -1r "${backup_file_dir}" | sed -nr '/^[0-9]*'$fid'\.tar\.gz$/{s/\.tar\.gz//p;q}' )
			;;
	esac
	if [ -z "$fid" ] ; then
		echo "Error: No file can be load."
		exit 1
	elif ! [ -a "${backup_file_dir}/${fid}.tar.gz" ] ; then
		echo "Error: No search file ID similar to $fid_old in ${backup_file_dir}"
		exit 1
	fi

}

get_fid_new(){
	# This function will get a new ID.
	# if no search last ID, It will give a new id too.
	#local fid_last=( $(ls -1 "${backup_file_dir}" |sed -nr 's/([0-9]{8})([0-9]{2})\.tar.gz$/\1 \2/p'|tail -n 1) )
	local fid_last=( $(ls -1r "${backup_file_dir}" | sed -nr '0,/^([0-9]{10})\.tar\.gz$/{s/([0-9]{8})([0-9]{2})\.tar\.gz$/\1 \2/p}') )
	
	if [ "${fid_last[1]}" -ge 99 ] ; then
		echo "Warn: Today had 99 records, please take a rest.  :)"
		exit 1
	fi
	
	if [ "$(date +%Y%m%d)" == "${fid_last[0]}" ] ; then
		fid=$( printf "%d%02d\n" ${fid_last[0]} $((10#${fid_last[1]}+1)) )	# base is 10
	else
		fid="$(date +%Y%m%d)01"
	fi
}

mk_comment_header(){
	# header for txt2tags
	echo "${game_name} backup comment. support txt2tags format." > "${backup_file_dir}/${comment_file}"
	echo "${USER}" >> "${backup_file_dir}/${comment_file}"
	echo '%%date' >> "${backup_file_dir}/${comment_file}"
	# setting of txt2tags
	echo "" >> ${backup_file_dir}/${comment_file}
}
write_comment(){	# usage : write_comment $fid $title
	[ -s "${backup_file_dir}/${comment_file}" ] || mk_comment_header
	echo "==${1} ${2}==" >> "${backup_file_dir}/${comment_file}"
	echo "" >> "${backup_file_dir}/${comment_file}"
}

read_comment(){		# usage : read_comment $fid
	
	if [ -a "${backup_file_dir}/${comment_file}" ] ; then
		sed -nr '/^=='${1}' .*==$/,/^==[0-9]{10} .*==$/ {s/^=='${1}' (.*)==$/\1/; /^==[0-9]{10} .*==$/b; p}' "${backup_file_dir}/${comment_file}"
		return 0
	else
		echo "Error : There is no ${comment_file} in ${backup_file_dir}"
		return 1
	fi
	
}
delete_comment(){	# usage : delete_comment $fid
	
	# delete title to next title
	sed -ri '/^=='${1}' .*==$/,/^==[0-9]{10} .*==$/ {/^=='${1}' .*==$/d; /^==[0-9]{10} .*==$/b; d}' "${comment_file}"
	
	
}
print_comment(){	# usage : print_comment $fid
	echo "_____ ${1} _____"                                                                                                               
	local cmt="$(read_comment ${1} )"
	echo "<<< $(echo "$cmt" | sed -n '1p' ) >>>"	# Title
	echo "$(echo "$cmt" | sed -n '2,$p' )"
}
mv_trash(){		# usage : mv_trash $fid
	[ -d "${trash_dir}" ] || `mkdir "${trash_dir}"`
	if [ "$1" != "tmp" ] ; then
		read_comment ${1} >  "${backup_file_dir}/comment_${1}.txt"
		delete_comment ${1}
		gzip -d "${backup_file_dir}/${1}.tar.gz"
		tar -rf "${backup_file_dir}/${1}.tar" -C "${backup_file_dir}" "comment_${1}.txt"
		gzip "${backup_file_dir}/${1}.tar"
		rm "${backup_file_dir}/comment_${1}.txt"
	fi
	# add delete date and id before original file name
	
	#local fid_last=( $(ls -1 "${trash_dir}" |sed -nr 's/([0-9]{8})([0-9]{2})-.*\.tar.gz$/\1 \2/p'|tail -n 1) )
	local fid_last=( $(ls -1r "${trash_dir}" | sed -nr '0,/^([0-9]{10})-.*\.tar\.gz$/{s/([0-9]{8})([0-9]{2})-.*\.tar\.gz$/\1 \2/p}') )
	if [ "$(date +%Y%m%d)" == "${fid_last[0]}" ] ; then
		local fid_del="$( printf "%d%02d\n" ${fid_last[0]} $((10#${fid_last[1]}+1)) )-${1}"
	else
		local fid_del="$(date +%Y%m%d)01-${1}"
	fi
	
	mv "${backup_file_dir}/${1}.tar.gz" "${trash_dir}/${fid_del}.tar.gz"
	# Check trash file number
	# it's will rm more then 30 (write after sed). find for send absolute path of file to xargs.
	find "${trash_dir}" -regextype posix-extended -regex '.*[0-9]{10}-.*.tar.gz'|sort -r |sed -n '31,$ p' | xargs --no-run-if-empty rm
	
}


# Parsing command line arguments
fid=""
op=""
set -o noglob	# for "*" in $* , if no add this line , * will expansion.
while [ $# -gt 0 ]
do
	case "$1" in
		-sn)	op="save_to_new"	;;
		-st) 	op="save_to_tmp"	;;
		-ln)	op="load_normal"
			if [[ "$2" =~ [0-9]{1,10} ]] ; then
				fid=$2
				shift
			fi
			;;
		-lt)	op="load_tmp"		;;
		-dn)	op="delete_normal"
			if [[ "$2" =~ [0-9]{1,10} ]] ; then
				fid=$2
				shift
			fi
			;;
		-dt)	op="delete_tmp"		;;
		-mt)	op="move_tmp"		;;
		-lc)	op="list_comment"	
			if [[ "$2" =~ [0-9]{1,10} ]] ; then
				fid=$2
				shift
			fi
			;;
		-ec)	op="edit_comment"
			if [[ "$2" =~ [0-9]{1,10} ]] ; then
				fid=$2
				shift
			else
				echo "Plese select a file ID"
				op="list_comment"
			fi
			;;
		-h )	op="help-short"
			;;
 		-hf )	op="help-full"
			;;
		-xch )	op="export_comment_html"
			;;
		*)  	arg=( ${arg[*]} $1)
			;;
	esac
	shift
done
comment_title="${arg[*]}"
#set +o noglob

if [ -z "$op" ] ; then
	echo "Error : Invalid option."
	op="help-short"
elif [ "$op" == "list_comment" -o "$op" == "edit_comment" -o "$op" == "export_comment_html" ] ; then 
	if ! [ -a "${backup_file_dir}/${comment_file}" ] ; then
		echo "Error : There is no ${comment_file} in ${backup_file_dir}"
		exit 1
	fi
fi

# check folder
if [ "$op" != "help-short" ] && [ "$op" != "help-full" ] ; then
	if ! [ -a "${game_files}" ] ; then
		echo -e "Error: Backup target not found. please check config in script. \\n"
		op="help-full"
	elif [ ! -d "${backup_file_dir}" ] ; then
		read -p "There is no backup folder ( ${backup_file_dir} ), make new one? [y/n] " -t 10 ans
		if [[ "$ans" =~ [yY] ]] ; then
			mkdir -p "${backup_file_dir}" || { echo "Error: Can't make folder in  ${backup_file_dir}"; exit 1 ;}
		else
			echo "Error : This script need a backup folder !"
			echo "Please use \"$(basename $0) -hf\" to get more infomation."
			exit 1
		fi
	fi
fi



# check fid is number only

case "${op}" in
	"help-short" )
	echo "
Option:
	-sn [Title]	Save to new backup.
	-st		Save to temporary backup. Can't add comment
	-ln [ID]	Load backup file from (normal) backup
	-lt		Load backup file from temporary backup
	-dn [ID]	Delete normal backup file
	-dt		Delete temporary backup file
	-mt [Title]	Move temporary to normal
	-lc [ID]	List comment titles or watch special comment
	-ec ID		Edit special comment
	-h		Show short help message.
	-hf		Show full help message.(include how to install)
	-xch		Export to HTML file by txt2tags
"
	;;
	"help-full" )
	echo "
Introduction:
	This script can help you backup/restore file.
	Aim for game record, but not only game.
	In Taiwan, we call this \"SL magic\". 
	
	Feature : 
	1. Easy backup and restore
	2. Comment each backup. You can edit later and export by txt2tags.
	3. Backup is compressd.
	4. Portable, backup files and comment in same folder.
	5. One script for different game.

Synopsis:
	$(basename $0) [OPTION] [BACKUP ID | COMMENT TITLE]

Option:
	-sn [Title]	Save to new backup.
	-st		Save to temporary backup. Can't add comment
	-ln [ID]	Load backup file from (normal) backup
	-lt		Load backup file from temporary backup
	-dn [ID]	Delete normal backup file
	-dt		Delete temporary backup file
	-mt [Title]	Move temporary to normal
	-lc [ID]	List comment titles or watch special comment
	-ec ID		Edit special comment
	-h		Show short help message.
	-hf		Show full help message.(include how to install)
	-xch		Export to HTML file by txt2tags
	
	ID format is YYYYMMDDNN. (Year,Month,Date,Number[max=99])
	You can only use partial ID, It can be identify. If you
	don't special ID, default is last.
	
Example:
	Backup files
		$(basename $0) -sn
		$(basename $0) -sn It\'s a big step.
		(You nees add \ before ' \" * because shell )
	
	Load backup file
		$(basename $0) -ln
		$(basename $0) -ln 2013112201
		$(basename $0) -ln 1
		(Use partial ID)

Configure: 
	This script can backup single path (include file and folder),
	You need special which is backup target and where is backup folder.
	Please edit \"database var\" section in this script. Change the game 
	name and path.
	eg:db_game_files[\"gamename\"]=\"path\" 

	For more backup target,add path variable pair to \"database var\" 
	section. Change the name of script to sl-gamename.sh
	(replace gamename to what you want.)
	You can use (hard) links to save space by different link name.
	
	The default editor is vi. If you don't like it, please change code
	by replace 'vi' word. (I want use eval, but busybox no eval ... )

Author:
	Written by sppmg ( https://github.com/sppmg )
	Version = ${version}

Copyright:
	This is free software: you are free to change and redistribute it.
	There is NO WARRANTY, to the extent permitted by law.
"
		;;
	"save_to_new" )
		get_fid_new
		tar -czf "${backup_file_dir}/${fid}.tar.gz" -C "${game_dir}" "${game_target}" || { echo "Error: Can't save file to ${backup_file_dir}/${fid}.tar.gz" ; exit 1 ; }
		write_comment $fid "$comment_title"
		echo Saved to ${fid}
		;;
	"save_to_tmp" )
		# No check overwrite here.
		tar -czf "${backup_file_dir}/tmp.tar.gz" -C "${game_dir}" "${game_target}" ||  { echo "Error: Can't save file to ${backup_file_dir}/tmp.tar.gz" ; exit 1 ; }
		echo Saved to tmp
		;;
	"load_normal" )
		get_fid_last
		print_comment $fid
		read -p "Overwrite \"${game_files}\" by $fid ? [y/n] " -t 10 ans
		if [[ "$ans" =~ [yY] ]] ; then
			tar -xzf "${backup_file_dir}/${fid}.tar.gz" -C "${game_dir}" || { echo "Error: Can't load file from ${backup_file_dir}/${fid}.tar.gz" ; exit 1 ; }
			echo loaded ${fid}
		else 
			echo Canceled
		fi
		;;
	"load_tmp" )
		[ -a "${backup_file_dir}/tmp.tar.gz" ] || { echo "Error: There is no tmp file in ${backup_file_dir}" ; exit 1 ; }
		read -p "Overwrite \"${game_files}\" by tmp ? [y/n] " -t 10 ans
		if [[ "$ans" =~ [yY] ]] ; then
			tar -xzf "${backup_file_dir}/tmp.tar.gz" -C "${game_dir}" || { echo "Error: Can't load file from ${backup_file_dir}/tmp.tar.gz" ; exit 1 ; }
			echo Loaded tmp
		else 
			echo Canceled
		fi
		
		;;
	"delete_normal" )
		get_fid_last
		print_comment $fid
		echo ----------------------	
		read -p "Delete $fid ? [y/n] " -t 10 ans
		if [[ "$ans" =~ [yY] ]] ; then
			mv_trash "${fid}"
			echo Deleted
		else 
			echo Canceled
		fi
		
		;;
	"delete_tmp" )
		[ -a "${backup_file_dir}/tmp.tar.gz" ] || { echo "Error: There is no tmp file in ${backup_file_dir}" ; exit 1 ; }
		read -p "Delete tmp file? [y/n] " -t 10 ans
		if [[ "$ans" =~ [yY] ]] ; then
			mv_trash "tmp"
			echo Deleted
		else 
			echo Canceled
		fi
		;;
	"move_tmp" )
		[ -a "${backup_file_dir}/tmp.tar.gz" ] || { echo "Error: There is no tmp file in ${backup_file_dir}" ; exit 1 ; }
		get_fid_new
		cp "${backup_file_dir}"/{tmp.tar.gz,"${fid}".tar.gz} || { echo "Error: Can't load file from ${backup_file_dir}/tmp.tar.gz" ; exit 1 ; }
		# add comment
		echo "Created new file $fid from tmp"
		# Don't add this check to -sn because speed.
		if [ -z "$comment_title" ] ; then
			read -p "Type a title of comment? [y/n] " -t 10 ans
			if [[ "$ans" =~ [yY] ]] ; then
				read -p "Title > " comment_title
			fi
		fi
		write_comment "$fid" "$comment_title"
		;;
	"list_comment" )
		if [ -z "$fid" ] ; then
			sed -nr -e 's/^==([0-9]{10}) (.*)==$/\1 -> \2/gp' "${backup_file_dir}/${comment_file}" |sort 
			echo "Comment in ${backup_file_dir}/${comment_file}"
		else
			get_fid_last
			print_comment $fid
		fi
		;;
	"edit_comment" )
		# get title and content and save to tmp file
		# this tmp file formated (delete txt2tags title mark '= = ' and last blank line)
		get_fid_last
		read -p "Edit comment of ${fid} ? [y/n] " -t 10 ans
		if [[ "$ans" =~ [nN] ]] ; then
			echo Canceled
			exit 0
		fi
		
		read_comment ${fid} >  "${backup_file_dir}/comment_new_${fid}.txt"
		vi "${backup_file_dir}/comment_new_${fid}.txt"
		
		# format new text file
			# translate first line to title form
		sed -ri '1 {s/(.*)/=='${fid}' \1==/}' "${backup_file_dir}/comment_new_${fid}.txt"
			# make sure last line is blank (I don't know how to combine to 1 line command.)
		last_line=$(sed -nr '$ {/^$/!p}' "${backup_file_dir}/comment_new_${fid}.txt")
		[ -n "$last_line" ] && $(echo "" >> "${backup_file_dir}/comment_new_${fid}.txt")
		
		# inster new comment text. inster mark line -> delete fid's comment -> inster new comment -> delete mark word.
		
		random_str="$(dd if=/dev/urandom bs=100 count=1 2>/dev/null | base64 |sed ':a;N;$!ba;s/[\n/+=]//g')" # include [a-Z,0-9],sed removed "\n" "/" "+" "="
		
		# random_str_int=${RANDOM}${RANDOM}${RANDOM}${RANDOM}${RANDOM}	# 0-32767 for each $RANDOM
		mark_line="comment_tmp_mark_${random_str}"
		
		sed -r -e '/^=='${fid}' .*==$/i '${mark_line} -e '/^=='${fid}' .*==$/,/^==[0-9]{10} .*==$/ {/^=='${fid}' .*==$/d; /^==[0-9]{10} .*==$/b; d}' "${backup_file_dir}/${comment_file}" | sed -r -e '/^'${mark_line}'$/r '"${backup_file_dir}/comment_new_${fid}.txt" -e '/^'${mark_line}'$/d' > "${backup_file_dir}/${comment_file}.tmp"
		
		mv "${backup_file_dir}"/{"${comment_file}.tmp","${comment_file}"}
		# delete temporary file
		rm "${backup_file_dir}/comment_new_${fid}.txt"
		;;
	"export_comment_html" )
		txt2tags -q -t html -i "${backup_file_dir}/${comment_file}" -o "${backup_file_dir}/${comment_file}.html" && echo "Exported comments to ${backup_file_dir}/${comment_file}.html"
		;;
		
esac
