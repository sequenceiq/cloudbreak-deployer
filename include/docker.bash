docker-check-docker-machine() {
    if ! docker-machine version &> /dev/null; then
        error "docker-machine command not found, please install by:"
        echo "  brew install docker-machine" | blue
        _exit 127
    fi
    if [[ "$(docker-machine status $DOCKER_MACHINE)" == "Running" ]]; then
      if [[ "$DOCKER_HOST" = *"$(docker-machine ip $DOCKER_MACHINE)"* ]]; then
          info "docker-machine env init: OK"
      else
          error "docker-machine env is not set correctly, please run:"
          echo " eval \$(docker-machine env $DOCKER_MACHINE)" | blue
          _exit 125
      fi
    else
      error "docker-machine is not running, please start by:"
      echo "  docker-machine start $DOCKER_MACHINE" | blue
      _exit 126
    fi

    info "docker-machine: OK" | green
}

docker-getversion() {
    declare desc="Gets the numeric version from version string"

    local versionstr="$*"
    debug versionstr=$versionstr
    local fullver=$(echo "${versionstr%%,*}" |sed "s/.*version[ :]*//")
    debug fullver=$fullver
    # remove -rc2 and similar
    local numver=$(echo ${fullver%-*} | sed "s/\.//g")
    debug numver=$numver

    echo $numver
}

docker-check-client-version() {
    local ver=$(docker --version 2> /dev/null)
    local numver=$(docker-getversion $ver)

    if [ $numver -lt 180 ]; then
        local target=$(which docker 2>/dev/null || true)
        : ${target:=/usr/local/bin/docker}
        error "Please upgrade your docker version to 1.8.0 or latest"
        echo "suggested command:"
        echo "  sudo curl -Lo $target https://get.docker.com/builds/$(uname -s)/$(uname -m)/docker-latest ; chmod +x $target" | blue
        _exit 1
    fi

    echo-n "docker client version: "
    docker version -f '{{.Client.Version}}' | green

}

docker-check-server-version() {
    local numserver
    # since docker 1.8.1 docker version supports --format
    if docker version --help | grep -q -- '--format'; then
        local serverVer=$(docker version -f "{{.Server.Version}}")
        debug "serverVer=$serverVer"
        if [ $(version-compare "${serverVer}" "1.8.0") -lt 0 ]; then
            error "Please upgrade your docker version to 1.8.0 or latest"
            warn "your local docker seems to be fine, only the server version is outdated"
            _exit 1
        fi
    else
        local serverVer=$(docker version 2> /dev/null | grep "Server version")
        debug "serverVer=$serverVer"
        numserver=$(docker-getversion $serverVer)
        if [ $numserver -lt 180 ]; then
            error "Please upgrade your docker version to 1.8.0 or latest"
            warn "your local docker seems to be fine, only the server version is outdated"
            _exit 1
        fi
    fi

    echo-n "docker client version: "
    docker version -f '{{.Server.Version}}' | green
}

docker-check-version() {
    declare desc="Checks if docker is at least 1.8.0"

    echo-n "docker command exists: "
    if command_exists docker; then
        info "OK"
    else
        error
        exit 1
    fi

    docker-check-client-version
    docker-check-server-version
}

docker-kill-all-sidekicks() {
    debug "kill all exited container labeled as: cbreak.sidekick"
    ( docker rm -f $(docker ps -qa -f 'label=cbreak.sidekick' -f status=exited ) & ) &>/dev/null
}
