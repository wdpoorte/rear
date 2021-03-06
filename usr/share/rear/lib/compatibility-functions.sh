# put all disaster recovery related functions here


if has_binary vol_id; then
    Debug "Using 'vol_id' for rear_vol_id"
    function rear_vol_id {
        vol_id $@
    }
elif has_binary udev_volume_id; then
    Debug "Using 'udev_volume_id' for rear_vol_id"
    # vol_id does not exist, but the older udev_volume_id is available
    # we write a little wrapper to map udev_volume_id to vol_id

    # output of udev_volume_id looks like this:
        # F:filesystem
        # T:ext3
        # V:
        # L:boot
        # N:boot
        # U:eddf2e10-0adb-40a8-af88-027ef9710953

    # output of vol_id (and this function) looks like this:
        # ID_FS_USAGE='filesystem'
        # ID_FS_TYPE='ext3'
        # ID_FS_VERSION=''
        # ID_FS_LABEL='boot'
        # ID_FS_LABEL_SAFE='boot'
        # ID_FS_UUID='eddf2e10-0adb-40a8-af88-027ef9710953'

    # NOTE: vol_id returns different exit codes depending on the error (file not found, unknown volume, ...)
    #       But udev_volume_id returns 0 even on unknown volume.
    #   To better mimic the vol_id behaviour we return 0 only if there is some real information
    #   which we detect by searching for the = sign in the KEY=VAL result produced by sed
    #   Furthermore, the grep = prevents non-KEY=VAL lines to be returned, which would confuse
    #   the calling eval $(vol_id <device>) statement.

    function rear_vol_id {
        udev_volume_id "$1" | sed \
            -e "s/^F:\(.*\)$/ID_FS_USAGE='\1'/" \
            -e "s/^T:\(.*\)$/ID_FS_TYPE='\1'/" \
            -e "s/^V:\(.*\)$/ID_FS_VERSION='\1'/" \
            -e "s/^L:\(.*\)$/ID_FS_LABEL='\1'/" \
            -e "s/^N:\(.*\)/ID_FS_LABEL_SAFE='\1'/" \
            -e "s/^U:\(.*\)/ID_FS_UUID='\1'/" | grep =
    }
# NOTE: We use blkid ONLY if it is a newer one and reports information back in udev-style
elif has_binary blkid && blkid -o udev >&8 2>&1; then
    Debug "Using 'blkid' for rear_vol_id"
    # since udev 142 vol_id was removed and udev depends on blkid
    # blkid -o udev returns the same output as vol_id used to
    #
    # NOTE: The vol_id compatible output was added to blkid at version ? (FIXME)
    function rear_vol_id {
        blkid -o udev -p "$1"
    }

    # BIG WARNING! I added this to support openSUSE 11.2 which removed vol_id between m2 and m6 (!!) by updating udev
    #
    # SADLY blkid on Fedora 10 and openSUSE 11.1 (for example) behaves totally different. Additionally I found out
    # that on Fedora 10 and openSUSE 11.1 blkid comes from e2fsprogs and on openSUSE 11.2m6 blkid comes from
    # util-linux (which is util-linux-ng !)
    #
    # IT REMAINS TO BE OBSERVED how this story continues and whether all systems that do NOT have vol_id DO have
    # a suitable blkid installed.
    #
# everybody else gets to use our built-in rear_vol_id
else
    Debug "Using internal version for rear_vol_id"
    if [ "$WARN_MISSING_VOL_ID" ]; then
        Log "Required udev program 'vol_id' or a suitable 'blkid' could not be found !
Activating a very primitive builtin replacement that supports
ext2/3:   LABEL and UUID
reiserfs: LABEL
xfs:      LABEL and UUID
swap:     LABEL

WARNING ! This rear_vol_id wrapper has been tested on i386/x86_64 ONLY !!
"
    fi
    function rear_vol_id {
        case "$(file -sbL "$1")" in
        *ext*filesystem*)
            echo "ID_FS_USAGE='filesystem'"
            while IFS=: read key val junk ; do
                val="${val##*( )}"
                case "$key" in
                *features*)
                    if expr match "$val" ".*journal.*" >&8; then
                        echo "ID_FS_TYPE='ext3'"
                    else
                        echo "ID_FS_TYPE='ext2'"
                    fi
                    ;;
                *name*)
                    # <none> denotes an EMPTY label, so don't set one!
                    test "$val" = "<none>" && val=
                    echo "ID_FS_LABEL='$val'"
                    ;;
                *UUID*)
                    echo "ID_FS_UUID='$val'"
                    ;;
                esac
            # FIXME: What about RHEL5 using tune4fs instead of tune2fs for ext4?
            done < <(tune2fs -l "$1")
            ;;
        *ReiserFS*)
            echo "ID_FS_USAGE='filesystem'"
            echo "ID_FS_TYPE='reiserfs'"
            echo "ID_FS_LABEL='$(dd if="$1" bs=1 skip=$((0x10064)) count=64 2>&8)'"
            ;;
        *XFS*)
            echo "ID_FS_USAGE='filesystem'"
            echo "ID_FS_TYPE='xfs'"
            echo "ID_FS_LABEL='$(xfs_admin -l "$1" | cut -d \" -f 2)'"
            echo "ID_FS_UUID='$(xfs_admin -u "$1" | cut -d " " -f 3)'"
            ;;
        *swap*file*)
            echo "ID_FS_USAGE='other'"
            echo "ID_FS_TYPE='swap'"
            echo "ID_FS_VERSION='2'"
            echo "ID_FS_LABEL='$(dd if="$1" bs=1 skip=$((0x41c)) count=64 2>&8)'"
            ;;
        *)
            Error "Unsupported filesystem found on '$1'
file says: $(file -sbL "$1")
You might try to install the proper vol_id from the udev package to support
this filesystem."
        esac
    }
fi

# See
#   http://osdir.com/ml/bug-bash-gnu/2010-04/msg00080.html
#   http://stackoverflow.com/questions/2649240/bash-file-descriptor-leak
#   http://bugs.debian.org/cgi-bin/bugreport.cgi?bug=466138
#
# The way how we use Bash with lots of (nested) functions and read etc. seems to trigger a Bash
# bug that causes leaked file descriptors. lvm likes to complain about that but since we
# cannot fix the bash we suppress these lvm warnings:
export LVM_SUPPRESS_FD_WARNINGS=1
