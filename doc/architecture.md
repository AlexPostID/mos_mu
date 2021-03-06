
## Table of Contents
 - [Inventory](#inventory)
 - [Folder structure](#folder-structure)
   - [Fuel](#fuel)
   - [Nodes](#nodes)
 - [Tasks](#tasks)
   - [apt_update.yml](#apt_updateyml)
   - [get_current_mu.yml](#get_current_muyml)
   - [verify_md5.yml](#verify_md5yml)
   - [clean_customizations.yml](#clean_customizationsyml)
   - [gather_current_customizations.yml](#gather_current_customizationsyml)
   - [verify_patches.yml](#verify_patchesyml)
   - [apt_upgrade.yml](#apt_upgradeyml)
   - [apply_patches.yml](#apply_patchesyml)
   - [rollback_upgrade.yml](#rollback_upgradeyml)
 - [Playbooks](#playbooks)
   - [gather_customizations.yml](#gather_customizationsyml)
   - [verify_patches.yml](#verify_patchesyml)
   - [apply_mu.yml](#apply_patchesyml)
   - [restart_services.yml](#restart_servicesyml)
   - [rollback.yml](#rollbackyml)


Inventory
=========

Inventory Python script generates inventory data for Ansible using Fuel API.
For review inventory you can run this script separately.

[fuel_inventory.py](../inventory/fuel_inventory.py)

Folder structure
================

By default it looks like this (might be configured in conf file):

Fuel
----

Variables in config:
```
fuel_dir:         "/root/fuel_mos_mu"
fuel_custom_dir:  "{{ fuel_dir }}/customizations"
fuel_patches_dir: "{{ fuel_dir }}/patches"
```

Directory tree:
```
/root/fuel_mos_mu
├── customizations
│   └── node-3
│       └── python-neutron_customization.patch
└── patches
    └── 01-python-nova.patch
```

* Folder **customizations** is used for gathering customizations from nodes.
  Customizations are placed in folder with nodename.
  This folder will be cleared task
  [gather_customizations.yml](#gather_current_customizationsyml) will be run
  with flag **clean_customizations: true**.
  Please be careful with this flag since you can loose your customizations.

* Folder **patches** is used for storing set of patches which will be synced
  on nodes and used for verifying applying and applying on cloud.
  Patches should have **.patch** extensions. Please be aware that patches
  will be applied in alphabetic order, also keep in mind that if flag
  **use_current_customizations: true** is enabled current customizations
  will be also copied to **patches** folder on nodes with to
  **00-customizations** folder.
  So it is recommended to name patches with prefixes like this
  **01-\<patchname\>.patch, 02-\<patchname2\>.patch**.

Nodes
-----

Variables in config:
```
mos_dir:          "/root/mos_mu"
custom_dir:       "{{ mos_dir }}/customizations"
patches_dir:      "{{ mos_dir }}/patches"
verification_dir: "{{ mos_dir }}/verification"
apt_dir:          "{{ mos_dir }}/apt"
apt_conf:         "{{ apt_dir }}/apt.conf"
apt_src_dir:      "{{ apt_dir }}/sources.list.d"
```

Direrctory tree:
```
/root/mos_mu/
├── apt
│   ├── apt.conf
│   └── sources.list.d
│       ├── fuel.list
│       ├── GA.list
│       ├── latest.list
│       ├── mu-1.list
│       ├── mu-2.list
│       ├── mu-3.list
│       └── mu-4.list
├── customizations
│   └── python-neutron
│       ├── 1%3a2015.1.1-1~u14.04+mos5341
│       │   └── usr
|       |         ............
│       └── python-neutron_customization.patch
├── patches
│   ├── 00-customizations
│   │   └── python-neutron_customization.patch
│   └── 01-python-nova.patch
└── verification
    ├── python-neutron
    │   ├── 1%3a2015.1.1-1~u14.04+mos5371
    │   │   ├── python-neutron_1%3a2015.1.1-1~u14.04+mos5371_all.deb
    │   │   └── usr
    |   |   |     ............
    │   └── python-neutron_customization.patch
    └── python-nova
        ├── 1%3a2015.1.1-1~u14.04+mos19695
        │   ├── python-nova_1%3a2015.1.1-1~u14.04+mos19695_all.deb
        │   └── usr
        |         ............
        └── 01-python-nova.patch
```

* Folder **apt** contains apt.conf which is always used for apt and uses
  only **sources.lists.d** folder for sources lists.

* **apt/sources.list.d** contains sources lists for all configured in config
  repositories.

* **customizations** folder consists of folders for customized packages.
  Packages folder contains folder (current package version) with unpacked
  package and diff file between this unpacked version and current installed
  (customized) version.

* **patches** folder contains all patches from Fuel **patches** folder and
  current customizations **00-customizations** if flag
  **use_current_customizations: true** is enabled. This folder is cleared every
  time when task [verify_patches.yml](#verify_patchesyml) is started.

* **verification** folder consists of folders for customized packages.
  Packages folder contains folder (candidate package version, by default,
  configured by flag **pkg_ver_for_verifiacation: "Candidate"**) with unpacked
  package and patches files witch should be applied.


Tasks
=====

[apt_update.yml](../playbooks/tasks/apt_update.yml)
---------------------------------------------------


* Clean **apt** folder on nodes.
* Generate and copy on nodes sources.list files from
  [templates/sources.list.j2](../playbooks/templates/sources.list.j2) using i
  configuring repositories in conf file.
* Generate and copy on nodes **apt.conf** file from
  [templates/apt_conf.j2](../playbooks/templates/apt.conf.j2).
* Perform APT update using generated **apt.conf** on nodes.

[get_current_mu.yml](../playbooks/tasks/get_current_mu.yml)
-----------------------------------------------------------

* Run [files/get_current_mu.sh](../playbooks/files/get_current_mu.sh) script to
  identify which MU currently is applied. Actually this script just uses one by
  one sources.list from sources.list.d folder and check if any package have
  available 'update'.  If noone have update it means that exactly this MU is
  installed now. It can return 'undefine' result, that means the node has
  installed packages from different MU(or other undefined) repos.

[verify_md5.yml](../playbooks/tasks/verify_md5.yml)
---------------------------------------------------

* Run [files/verify_packages_ubuntu.sh](../playbooks/files/verify_packages_ubuntu.sh)
  script which for all installed python packages calculate MD5 sum and compared
  with origin.
* Return list of customized packages in **md5_verify_result** variable.

[clean_customizations.yml](../playbooks/tasks/clean_customizations.yml)
-----------------------------------------------------------------------

* Delete **customizations** folder on Fuel.
* Delete **customizations** folder on nodes.

[gather_customizations.yml](../playbooks/tasks/gather_customizations.yml)
-------------------------------------------------------------------------

* Check if customizations are already gathered ( **customization** folder exits
  on nodes ).
* Create **customizations** folder if doesn't exist.
* If doesn't exist for each customized package in **md5_verify_result** run s
  [files/get_package_customizations.sh](../playbooks/files/get_package_customizations.sh).
  This script unpacks cached origin installed package (or download if cached does
  not exist) and make a diff between origin and current state.
* If customizations were gathered, download them on Fuel in
  **customizations/\<nodename\>**.

[verify_patches.yml](../playbooks/tasks/verify_patches.yml)
-----------------------------------------------------------

* Clean **patches** folder on nodes.
* Clean **verification** folder on nodes.
* Copy patches from Fuel folder **patches** to nodes folder **patches**
  (if **rollback** is not enabled).
* Run [files/use_customizations.sh](../playbooks/files/use_customizations.sh)
  script which copy current patches from **customizations** folder to
  **patches** folder (if **use_curret_customization** is enabled).
* Run [files/verify_patches.sh](../playbooks/files/verify_patches.sh) script
  which:
    * Make sure that each patch affects only one package.
    * Download and extract candidate package if it does not already exist.
    * Try to apply patch. If more than 1 patch affects this package they will
      be applied in alphabetic order.

[apt_upgrade.yml](../playbooks/tasks/apt_upgrade.yml)
-----------------------------------------------------

* Correct dependencies.
* Perform APT upgrade.
* Reinstall customized packages

[apply_patches.yml](../playbooks/tasks/apply_patches.yml)
---------------------------------------------------------

* Run [files/apply_patches.sh](../playbooks/files/apply_patches.sh) script
  which just applies sorted by relative name patches in **patches** folder on
  nodes.

[rollback_upgrade.yml](../playbooks/tasks/rollback_upgrade.yml)
---------------------------------------------------------------

* Correct dependencies.
* Perform APT upgrade using only specified in variable **rollback** MU name.
* Reinstall customized packages

Playbooks
=========

By default all playbooks are defined for all nodes except Fuel.
It might be run for any node and group of nodes using standard flag **--limit**
like this `--limit=cluster_2:compute` (all computes in cluster_2).

All playbooks include variable file
[vars/mos_releases/{{ mos_release }}.yml](../playbooks/vars/mos_releases)
based on **mos_release** variable, which dynamically defined during
the inventarization phase.

Also it is possible to pass extra variables via cli using standard flag **-e**,
like this `-e '{"apt_update":false, "verify_md5":true}'`.

[gather_customizations.yml](../playbooks/gather_customizations.yml)
-------------------------------------------------------------------

Makes sure that customizations were not gathered already and then gathers them.
If you need to gather it again you can use flag **clean_customizations**.

Runs the set of tasks based on set of flags which allow or deny executing some
tasks. Uses
[vars/steps/gather_customizations.yml](../playbooks/vars/steps/gather_customizations.yml)
set of flags.

Run the following tasks:
* [apt_update.yml](#apt_updateyml)
* [get_current_mu.yml](#get_current_muyml)
* [verify_md5.yml](#verify_md5yml)
* [clean_customizations.yml](#clean_customizationsyml)
* [gather_customizations.yml](#clean_customizationsyml)

[verify_patches.yml](../playbooks/verify_patches.yml)
-----------------------------------------------------

Just verify applying patches on target version of packages
**pkg_ver_for_verifiacation**.

Uses [vars/steps/verify_patches.yml](../playbooks/vars/steps/verify_patches.yml)
set of flags.

Runs only two steps:
* [apt_update.yml](../playbooks/tasks/apt_update.yml)
* [verify_patches.yml](../playbooks/tasks/verify_patches.yml)

[apply_mu.yml](../playbooks/apply_mu.yml)
-----------------------------------------

Apply MU, apply patches and re-apply current customizations(if enabled).

By default uses [var/steps/apply_mu.yml](../playbooks/vars/steps/apply_mu.yml)
set of flags.

Run the following tasks:
* [apt_update.yml](#apt_updateyml)
* [get_current_mu.yml](#get_current_muyml)
* [verify_md5.yml](#verify_md5yml)
* [clean_customizations.yml](#clean_customizationsyml)
* [gather_customizations.yml](#gather_customizationsyml)
* [verify_patches.yml](#verify_patchesyml)
* [apt_upgrade.yml](#apt_upgradeyml)
* [apply_patches.yml](#apply_patchesyml)

and then include one more playbook:
* [restart_services.yml](#restart_servicesyml)

[restart_services.yml](../playbooks/restart_services.yml)
---------------------------------------------------------

Restart all services for each role specified in
[vars/mos_releases/{{ mos_releases }}.yml](../playbooks/vars/mos_releases).

Might be used separately.

[rollback.yml](../playbooks/rollback.yml)
-----------------------------------------

This is pseudo rollback, since it does not save the current state, but provide
you a mechanism for install any MU release (that you have initially for
rollback) and apply gathered customizations, of course as usual with verifying
patches before installing.

Runs the following tasks:
* [apt_update.yml](#apt_updateyml)
* [verify_md5.yml](#verify_md5yml)
* [clean_customizations.yml](#clean_customizationsyml)
* [gather_customizations.yml](#gather_customizationsyml)
* [verify_patches.yml](#verify_patchesyml)
* [apt_upgrade.yml](#apt_upgradeyml)
* [apply_patches.yml](#apply_patchesyml)

and then include one more playbook:
* [restart_services.yml](#restart_servicesyml)

Uses [vars/steps/rollback.yml](../playbooks/vars/steps/rollback.yml) set of
flags.
