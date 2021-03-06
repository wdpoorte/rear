# 45_prepare_xinetd.sh
# prepare environment for xinetd for NBU services
# NBU only supports RHEL/SLES distributions and both use xinetd daemon

PROGS=( "${PROGS[@]}" xinetd )
COPY_AS_IS=( "${COPY_AS_IS[@]}" /etc/xinetd.conf /etc/xinetd.d/bpcd /etc/xinetd.d/vnetd /etc/xinetd.d/vopied )
cat >$ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh <<-EOF
echo "Starting a minimal xinetd daemon ..."
xinetd
EOF
chmod $v +x $ROOTFS_DIR/etc/scripts/system-setup.d/90-xinetd.sh >&2
