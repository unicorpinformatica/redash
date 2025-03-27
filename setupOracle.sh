#!/bin/bash
sudo apt-get update && sudo apt-get install -y libaio1 wget unzip
sudo mkdir /opt/oracle
cd /opt/oracle
sudo wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip \
    && sudo unzip instantclient-basic-linux.x64-19.6.0.0.0dbru.zip \
    && sudo rm -f instantclient-basic-linux.x64-19.6.0.0.0dbru.zip 

sudo wget https://download.oracle.com/otn_software/linux/instantclient/19600/\instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip \
    && sudo unzip \instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip \
    && sudo rm -f \instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip 

sudo echo /opt/oracle/instantclient_19_6 > /etc/ld.so.conf.d/oracle-instantclient.conf \
    && sudo ldconfig
