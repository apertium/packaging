#!/bin/bash
docker run -it --rm --name mxe --hostname mxe -e LANG=C.UTF-8 -e LC_ALL=C.UTF-8 -e DEBIAN_FRONTEND=noninteractive -e DEBCONF_NONINTERACTIVE_SEEN=true -e 'DEB_BUILD_OPTIONS=parallel=11' -v /root/.ssh:/root/.ssh -v $SSH_AUTH_SOCK:/ssh-agent -e SSH_AUTH_SOCK=/ssh-agent -v /opt/mxe:/opt -v /opt/mxe/tmp:/tmp mxe /bin/bash "$@"
