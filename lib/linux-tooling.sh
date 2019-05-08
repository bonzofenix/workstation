#!/bin/bash

sudo apt-get install -y silversearcher-ag

GOVENDOREXPERIMENT=1 go get github.com/git-duet/git-duet/...
