# README

Instalación de Harbor, una registry para imágenes Docker.
Funciona en Debian buster y Ubuntu 18.04.

---
# 1. Crear la VM a instalar

```bash
time ( vagrant up && vagrant reload ) # para levantar el nuevo kernel instalado

```

---
# 2. Instalar harbor mediante script bash


Ingresar con `vagrant ssh` y correr:

```bash
/vagrant/instala-harbor.sh
```

---
# A. Referencias

# A.1 Usadas en Vagrant / Ubuntu / Debian

* https://github.com/goharbor/harbor/blob/master/docs/1.10/index.md Docs
* https://thenewstack.io/tutorial-install-the-docker-harbor-registry-server-on-ubuntu-18-04/


# A.2. Mejoras a futuro

* https://computingforgeeks.com/how-to-install-harbor-docker-image-registry-on-centos-debian-ubuntu/ instalación sin SSL y con LetsEncrypt

* https://github.com/nicholasamorim/ansible-role-harbor An Ansible Role that installs Harbor.

* https://github.com/mkgin/ansible-vmware-harbor Work in progress. Currently deploys from a local file, tested on CentOS 7
* https://github.com/wikitops/ansible_harbor Ansible playbook to deploy harbor on Linux Vagrant instance. RedHat.
* https://www.techcrumble.net/2019/12/automated-vmware-harbor-registry-deployment-with-gitlab-terraform-and-ansible/

## A.2. Autenticación

* https://computingforgeeks.com/harbor-registry-ldap-integration/ LDAP
* https://goharbor.io/blogs/announcing-harbor-1.8/ OpenID Connect (OIDC)
* https://openid.net/connect/
