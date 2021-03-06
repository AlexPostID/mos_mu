
**WORK IN PROGRESS !!!**

Don't use it on production environment until it will be released !!!

If you have any questions please don't hesitate to ask me:

aepifanov@mirantis.com

Any comments/suggestions are welcome :)

Prerequisites:
--------------

- epel: `yum install https://dl.fedoraproject.org/pub/epel/epel-release-latest-6.noarch.rpm`
- centos: `yum -y reinstall centos-release`
- ansible: `yum -y install ansible`

Install:
--------

Clone Git repository from GitHub on Fuel Master node:
```
git clone https://github.com/aepifanov/mos_mu.git
```
Configuration file:
-------------------

Conf file contains very important step flags:

[Apply MU steps](playbooks/vars/steps/apply_mu.yml)

Documentation:
--------------

[Architecture](doc/architecture.md)

Usage:
------

For the first step we would recommend to gather current customizations:
```
ansible-playbook playbooks/gather_customizations.yml --limit="cluster_1"
```

Then check that all customizations are applied on new versions
```
ansible-playbook playbooks/verify_patches.yml --limit="cluster_1"
```

It is also strongly recommended to identify and copy common customizations in
**patches** folder on Fuel and disable **use_current_customization** flag and
manage patches to successfully execute previous **verify_patches.yml** step.

Then you can continue to apply MU on environment
```
ansible-playbook playbooks/apply_mu.yml --limit="cluster_1" -e '{"use_curret_customization":false}'
```

This playbook contains all previous steps as well, so it might be used from
the beginning, but in this case it will apply the current customizations
and patches from **patches** folder from Fuel on each node and you will
get exactly the same customizations that were before.

Rollback:
---------

Rollback (actually pseudo rollback) playbook can return your cluster on any
specified release and apply gathered customizations:
```
ansible-playbook playbooks/rollback.yml --limit="cluster_1" -e '{"rollback":"mu-1"}'
```
