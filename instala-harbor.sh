#!/usr/bin/env bash
# instala-harbor.sh

# https://thenewstack.io/tutorial-install-the-docker-harbor-registry-server-on-ubuntu-18-04/

# si hay DNS asociado, configurar manualmente HARBOR_DOMAIN_NAME
# si no hay DNS, la siguiente expresión obtiene el ip de las redes 192.168.x.y ó 10.x.y.z y lo usa
HARBOR_DOMAIN_NAME=$( hostname -I | tr " " "\012" | grep -v 10.0.2.15 | awk '/^(192.168|10)\./{print $1}' )

HARBOR_ADMIN_PASSWORD=Harbor12345
HARBOR_DATABASE_PASSWORD=root123

# https://github.com/docker/compose/releases/latest
DOCKER_COMPOSE_VERSION=1.25.3

##
# apaga y elimina las imágenes:
# sudo /usr/local/bin/docker-compose -f /home/vagrant/harbor/docker-compose.yml down --rmi all

##
# version de harbor
#
# https://github.com/goharbor/harbor/releases/latest
#
#harbor_version_deseada=v1.8.1
#harbor_version_deseada=v1.8.6
#harbor_version_deseada=v1.9.4
harbor_version_deseada=v1.10.0


instala_docker() {
  if [ -z "$(whereis -b docker  | cut -d: -f2)" ] 
  then
    sudo apt-get install docker.io -y
    sudo usermod -aG docker $USER
  fi

  if [ -z "$(whereis -b docker-compose  | cut -d: -f2)" ] 
  then
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
  fi
}


desactiva_apache2() {
  sudo systemctl stop apache2
  sudo systemctl disable apache2
}


instala_nginx() {
  sudo apt-get install nginx -y
  sudo systemctl start nginx
  sudo systemctl enable nginx
}

descarga_harbor() {

  harbor_url_version=$( curl --silent "https://api.github.com/repos/goharbor/harbor/releases"  | jq -r '.[] | select(.name|test("v[0-9]*.[0-9]*.[0-9]*$")) | .name ' | sort -rV | head -n1 )

  [ "${harbor_version_deseada}" != "${harbor_url_version}" ] && echo "CUIDADO: la version solicitada [${harbor_version_deseada}] NO ES IGUAL a la ultima disponible: [${harbor_url_version}]"

  # FIXME:
  #harbor_url_download=$( curl --silent "https://api.github.com/repos/goharbor/harbor/releases" | jq -r '.[].assets[] | select(.name == "harbor-offline-installer-'${harbor_version_deseada}'.tgz").browser_download_url' )

  harbor_url_download="https://github.com/goharbor/harbor/releases/download/${harbor_version_deseada}/harbor-offline-installer-${harbor_version_deseada}.tgz"


  harbor_filename="harbor-offline-installer-${harbor_version_deseada}.tgz"

  [ -f "${harbor_filename}" ] || wget "${harbor_url_download}"
  [ $? != 0 ] && exit 99

  tar xvzf "${harbor_filename}"
}


crea_claves_ssl_autofirmadas() {

  [ -f /etc/ssl/openssl.cnf.orig ] || sudo cp  /etc/ssl/openssl.cnf /etc/ssl/openssl.cnf.orig

  if ! grep -q "subjectAltName = IP:${HARBOR_DOMAIN_NAME}" /etc/ssl/openssl.cnf
  then
    sudo sed -i "/\[[ ]*v3_ca[ ]*\]/a subjectAltName = IP:${HARBOR_DOMAIN_NAME}"  /etc/ssl/openssl.cnf 
  fi

  cd ~/harbor/

  echo Generate the self-signed certificates
  openssl req -newkey rsa:4096 -nodes -sha256 -keyout ca.key \
    -x509  -days 3650 -out ca.crt \
    -subj "/C=AR/ST=Denial/L=Santa Fe/O=Dis/CN=${HARBOR_DOMAIN_NAME}"

  echo generate the signing request
  openssl req -newkey rsa:4096 -nodes -sha256 \
	  -keyout "${HARBOR_DOMAIN_NAME}" \
	  -out    "${HARBOR_DOMAIN_NAME}" \
          -subj "/C=AR/ST=Denial/L=Santa Fe/O=Dis/CN=${HARBOR_DOMAIN_NAME}"

  echo "subjectAltName = IP:${HARBOR_DOMAIN_NAME}" >> extfile.cnf

  echo Generate the certificate
  openssl x509 -req -days 3650 -in "${HARBOR_DOMAIN_NAME}" -CA ca.crt -CAkey ca.key -CAcreateserial -extfile extfile.cnf -out "${HARBOR_DOMAIN_NAME}"
}


copia_claves_al_docker() {

  cd ~/harbor/
  sudo mkdir -p /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}
  sudo cp *.crt *.key /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}
}


configura_instalador_harbor_10() {
  cd ~/harbor/
  [ -f harbor.yml.orig ] || sudo cp  harbor.yml harbor.yml.orig


    cat << EOF > harbor.yml
hostname: ${HARBOR_DOMAIN_NAME}

http:
  port: 8080

https:
   port: 443
   certificate: /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}/ca.crt
   private_key: /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}/ca.key

harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

database:
  password: ${HARBOR_DATABASE_PASSWORD}
  max_idle_conns: 50
  max_open_conns: 100

data_volume: /srv/data

clair:
  updaters_interval: 12

jobservice:
  max_job_workers: 10

notification:
  webhook_job_max_retry: 10

chart:
  absolute_url: disabled

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

#This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
_version: 1.10.0

proxy:
  http_proxy:
  https_proxy:
  # no_proxy endpoints will appended to 127.0.0.1,localhost,.local,.internal,log,db,redis,nginx,core,portal,postgresql,jobservice,registry,registryctl,clair,chartmuseum,notary-server
  no_proxy:
  components:
    - core
    - jobservice
    - clair

EOF

}



configura_instalador_harbor_9() {
  cd ~/harbor/
  [ -f harbor.yml.orig ] || sudo cp  harbor.yml harbor.yml.orig


  cat << EOF > harbor.yml
hostname: ${HARBOR_DOMAIN_NAME}

http:
  port: 8080

https:
   port: 443
   certificate: /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}/ca.crt
   private_key: /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}/ca.key

harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

database:
  password: ${HARBOR_DATABASE_PASSWORD}
  max_idle_conns: 50
  max_open_conns: 100

data_volume: /srv/data

clair:
  updaters_interval: 12

jobservice:
  max_job_workers: 10

notification:
  webhook_job_max_retry: 10

chart:
  absolute_url: disabled

log:
  level: info
  local:
    rotate_count: 50
    rotate_size: 200M
    location: /var/log/harbor

#This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
_version: 1.9.0

proxy:
  http_proxy:
  https_proxy:
  # no_proxy endpoint will append to already contained list:
  # 127.0.0.1,localhost,.local,.internal,log,db,redis,nginx,core,portal,postgresql,jobservice,registry,registryctl,clair,chartmuseum,notary-server
  no_proxy:
  components:
    - core
    - jobservice
    - clair
EOF


}


configura_instalador_harbor_8() {

  cd ~/harbor/
  [ -f harbor.yml.orig ] || sudo cp  harbor.yml harbor.yml.orig


  cat << EOF > harbor.yml
hostname: ${HARBOR_DOMAIN_NAME}

# http related config
http:
  port: 8080

https:
   port: 443
   certificate: /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}/ca.crt
   private_key: /etc/docker/certs.d/${HARBOR_DOMAIN_NAME}/ca.key

harbor_admin_password: ${HARBOR_ADMIN_PASSWORD}

database:
  password: ${HARBOR_DATABASE_PASSWORD}

data_volume: /srv/data

clair:
  updaters_interval: 12
  http_proxy:
  https_proxy:
  no_proxy: 127.0.0.1,localhost,core,registry

jobservice:
  max_job_workers: 10

chart:
  absolute_url: disabled

log:
  level: info
  rotate_count: 50
  rotate_size: 200M
  location: /var/log/harbor

#This attribute is for migrator to detect the version of the .cfg file, DO NOT MODIFY!
_version: 1.8.0
EOF


}


instala_harbor() {

  cd ~/harbor/
  sudo ./install.sh --with-clair
}


crea_servicio_systemd() {
  cat << EOF | sudo tee  /etc/systemd/system/harbor.service
[Unit]
Description=Harbor Service
After=network.target docker.service

[Service]
Type=simple
WorkingDirectory=/home/vagrant/harbor
ExecStart=/usr/local/bin/docker-compose -f /home/vagrant/harbor/docker-compose.yml up
ExecStop=/usr/local/bin/docker-compose -f /home/vagrant/harbor/docker-compose.yml down
RemainAfterExit=yes

[Install]
WantedBy=multi-user.target
EOF

  sudo systemctl enable harbor

  #sudo systemctl stop harbor
  sudo systemctl start harbor

  sudo systemctl status harbor

}


##
# main
#
sudo apt-get update -q
sudo apt-get install curl wget jq -y

instala_docker
desactiva_apache2
instala_nginx

# elimina una instalación anterior, si existiese:
sudo /usr/local/bin/docker-compose -f ~/harbor/docker-compose.yml down --rmi all
sudo rm -rf ~/harbor/

descarga_harbor
crea_claves_ssl_autofirmadas
copia_claves_al_docker

config_version=$(echo "${harbor_version_deseada}" | sed -e "s/^v\([0-9]*\.[0-9]*\)\..*/\\1/" -e "s/\./_/" )


[ "1_8"  == "${config_version}" ] && configura_instalador_harbor_8
[ "1_9"  == "${config_version}" ] && configura_instalador_harbor_9
[ "1_10" == "${config_version}" ] && configura_instalador_harbor_10

instala_harbor
crea_servicio_systemd


echo Ingresar a https://${HARBOR_DOMAIN_NAME}/harbor
echo con credenciales "admin / ${HARBOR_ADMIN_PASSWORD}"

