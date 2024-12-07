# RDO experimentation of S2I

This effort aims to build a set of container images from the OpenStack sources (i.e not from RPM).  
We want to fetch the source distributions from PyPi or directly from repositories if needed and build the wheels from it.    
Then we'd like to test the set of container images by deploying a minimal OpenStack infra with the OpenStack 
Kubernetes Operators.  

The container images are built on [Fedora Konflux instance](https://konflux.apps.kfluxfedorap01.toli.p1.openshiftapps.com/application-pipeline) within the `centos-cloud-sig`
tenant (c.f [see configuration](https://gitlab.com/fedora/infrastructure/konflux/tenants-config/-/tree/main/cluster/kfluxfedorap01/centos-cloud-sig?ref_type=heads)). Note that the tenant
is configured with minimal settings and default RBAC. Please check the [Fedora Konflux Cluster gist](https://gist.github.com/ralphbean/a3644111a549e8cedb0b207f90d42dc9#file-readme-md) for more details.

We are reusing the [TCIB](https://github.com/openstack-k8s-operators/tcib) container image definitions to do our test. [Here](https://softwarefactory-project.io/zuul/t/rdoproject.org/builds?job_name=validate-buildsys-tags-epoxy-testing-tcib-container-build-scenario000-centos9&project=rdoinfo) you can find the logs of the RDO CI job that build those TCIB container images with RDO RPMs.  

Konflux push the S2I container images to quay.io/repository/konflux-fedora/centos-cloud-sig [e.g openstack-base-centos10-epoxy](https://quay.io/repository/konflux-fedora/centos-cloud-sig/openstack-base-centos10-epoxy?tab=tags)

## To pin the dependencies
### RPMs
Those RPMs are mostly build-time dependencies required to build the wheels, but also to configure the system inside containers (at buildtime and/or runtime).
To generate the rpms.lock.yaml file
```
make lock-rpms
```
### Python modules
```
# pip-compile the requirements.in and requirements-build.in 
make pin-python-deps
# pull them with cachi2
make pull-python-deps
# try to install them in the same way Konflux does
make install-python-deps
```
#### To troubleshoot
If you want to operate inside the Cachi2 env.
Note that cachi2 env variables are already exported in shell env.
The cache dir is stored in a volume so wheels can be reused to speed up the development. If you want to build the wheels from scratch, please clear the cache directory with `pip cache purge` (see [pip cache doc](https://pip.pypa.io/en/stable/cli/pip_cache/)) for more details).
```
make run-dev-libs-image
pip wheel -v lxml
pip cache list
```
## TODO
- [ ] Move Containerfiles to multi-stage builds
- [ ] Make cryptography wheel compilation work on hermetic env (or take advantage of python3-cryptography RPM) 

## Issues
1. Konflux cannot verify RPM authenticity coming from [RDO Trunk centos10-epoxy repo](https://trunk.rdoproject.org/centos10-master/deps/latest/)
    - Konflux enabled `gpgcheck` by default (c.f [see config line](https://github.com/containerbuildsystem/cachi2/blob/7f09150bc4587ffa58cced9c76ea8de1cfec023e/cachi2/core/package_managers/rpm/main.py#L451))
    - Solution: use official CentOS Stream [Cloud SiG repo](https://buildlogs.centos.org/centos/10-stream/cloud/x86_64/openstack-epoxy/) where the RPMs are signed by the CentOS infra tooling.
2. DNF cannot verify the Cloud SiG RPMS as the Cloud SiG GPG pubkey is not yet shipped in CentOS Stream extras repo
    - [built](https://cbs.centos.org/koji/taskinfo?taskID=4341441) and tagged in [testing](https://cbs.centos.org/koji/taskinfo?taskID=4350817) and [release](https://cbs.centos.org/koji/taskinfo?taskID=4350818)
3. When building python from submodule repo and relying on [PBR](https://github.com/openstack/pbr) to guess version, it fails to get the right version.
    - that's because `git-clone` Tekton task performs a shallow clone of the submodule by fetching the latest commit ([see config](https://github.com/konflux-ci/build-definitions/blob/609f834ed3673445765d04e52844c1417e6ae065/task/git-clone/0.1/git-clone.yaml#L32)). But PBR expects a git tree with tags to guess the version, and PIP complains about it.
    - Solution: set defaut as [200](https://github.com/jcapiitao/rdo-konflux-s2i/blob/1cdf7b2728b591fc2e11562c3a1e7069a205b21c/.tekton/openstack-base-pull-request.yaml#L29) (could not find a way to set unlimited)
4. Building cryptography wheel requires access to public crates index, which is not possible in hermetic env.
    - for now I disabled hermetic env but I need to find a way to disallow cargo fetching public index or redirect it somehow to Cachi2.
