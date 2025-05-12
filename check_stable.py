#!/usr/bin/env python
# check_stable.py
#
# Retrieve latest stable version from static.rust-lang.org
# Compare the stable version to ensure we have a corresponding docker tag
#
# If we have not built it, print the version we need to build and exit 0
# If we have built it, exit 1

from urllib.error import HTTPError
import urllib.request as urllib
import json
import toml
import sys
import os

# Dockerhub repo to compare rust-lang release with
DOCKERHUB_REPO="beerpsi/cargo-chef-musl-mimalloc"

def rust_stable_version():
    """Retrieve the latest rust stable version from static.rust-lang.org"""
    url = 'https://static.rust-lang.org/dist/channel-rust-stable.toml'
    req = urllib.urlopen(url)
    data = toml.loads(req.read().decode("utf-8"))
    req.close()
    return data['pkg']['rust']['version'].split()[0]

def tag_exists(repo, tag):
    """Retrieve our built tags and check we have built a given one"""
    (namespace, repo) = repo.split("/")
    url = f'https://registry.hub.docker.com/v2/namespaces/{namespace}/repositories/{repo}/tags'

    try:
        req = urllib.urlopen(url)
    except HTTPError as e:
        if e.code == 404:
            return False
        
        print(e)
        sys.exit(0)

    data = json.loads(req.read())
    req.close()
    for x in data['results']:
        if x['name'] == tag:
            return True
    return False


if __name__ == '__main__':
    latest_stable = rust_stable_version()
    stable_tag = f'{latest_stable}-stable'
    if not tag_exists("clux/muslrust", stable_tag):
        print(f"upstream {stable_tag} has not been built, waiting for later")
        sys.exit(1)

    with open(os.environ["GITHUB_OUTPUT"], "a") as f:
        _ = f.write(f"MUSLRUST_VERSION={stable_tag}\n")
    
    if tag_exists(DOCKERHUB_REPO, stable_tag):
        print(f"tag {stable_tag} already built")
        sys.exit(1)
    
    print(f"need to build {latest_stable}")

    sys.exit(0)
