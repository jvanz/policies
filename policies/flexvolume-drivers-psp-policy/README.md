# Kubewarden policy psp-flexvolume-drivers

## Description

Replacement for the Kubernetes Pod Security Policy that controls Flex Volume drivers.

## Settings

This policy allows to provide a list of allowed Flex Volume drivers.

The configuration supports a list of allowed flex volume drivers. An example follows:

```yaml
allowedFlexVolumes:
  - driver: example/lvm
  - driver: example/cifs
```

If the pod to be evaluated has a different driver on any `flexVolume` volume, it will be rejected.

## License

```
Copyright (C) 2021 Rafael Fernández López <rfernandezlopez@suse.com>

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

   http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
```
