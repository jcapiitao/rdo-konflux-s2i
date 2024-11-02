# RDO experimentation of S2I

This project aims to build a set of container images from the OpenStack sources (not from RPM).  
We want to fetch the source distributions from PyPi or directly from repositories if needed and build the wheels from it.    
Then we'd like to test the set of container images by deploying a minimal OpenStack infra with the OpenStack 
Kubernetes Operators.  
The container images build is done on Fedora Konflux instance within the `centos-cloud-sig`
tenant.


# To pin the dependencies
## RPMs
Those RPMs are mostly build-time dependencies required to build the wheels, but also to configure the system inside containers.
To generate the rpms.lock.yaml file
```
make lock-rpms
```

## To update python dependencies
```
make pin-python-deps
make pull-python-deps
```

### to test the installation of the python deps
```
make install-python-deps
```
