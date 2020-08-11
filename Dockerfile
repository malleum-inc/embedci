FROM debian as builder

ARG QEMU_STATIC
ARG ARCH
ARG DEBIAN_VERSION=buster
ARG DEBIAN_VARIANT=minbase

COPY $QEMU_STATIC /usr/bin/$QEMU_STATIC

RUN apt update && \
       apt install -y debootstrap && \
       debootstrap --foreign --variant=$DEBIAN_VARIANT --arch=$ARCH $DEBIAN_VERSION /tmp/chroot && \
       ln -s /tmp/chroot/lib/ld-* /lib && \
       cp /usr/bin/$QEMU_STATIC /tmp/chroot/usr/bin && \
       DEBOOTSTRAP_DIR=/tmp/chroot/debootstrap debootstrap --second-stage --second-stage-target=/tmp/chroot && \
       rm -f /usr/bin/$QEMU_STATIC


FROM scratch

COPY --from=builder /tmp/chroot/ /

ENTRYPOINT ["/bin/bash"]