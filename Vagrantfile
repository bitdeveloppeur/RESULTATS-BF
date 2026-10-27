
# -*- mode: ruby -*-
# RÉSULTATS-BF - Infrastructure Vagrant
# Groupe 8 - Réseau 192.168.63.0/24

require 'yaml'
require 'fileutils'

# Configuration
GROUPE = (ENV['GROUPE'] || 8).to_i  # numéro de groupe, 1 à 8
NB_APP = (ENV['NB_APP'] || 2).to_i  # nombre de serveurs applicatifs

RESEAU = "192.168.#{55 + GROUPE}"
BOITE = "bento/ubuntu-24.04"
VERSION = "202404.26.0"  

# Validations
raise "GROUPE doit être compris entre 1 et 8" unless (1..8).include?(GROUPE)
raise "NB_APP doit être supérieur ou égal à 2" if NB_APP < 2

# Source unique de vérité : le Vagrantfile ET la configuration du
# répartiteur sont engendrés à partir de cette table.
NOEUDS = []

# Bases de données
NOEUDS << { nom: "bdd1", ip: "#{RESEAU}.31", mem: 768, role: "bdd" }
NOEUDS << { nom: "bdd2", ip: "#{RESEAU}.32", mem: 768, role: "replique" }

# Serveurs applicatifs (N paramétrable)
(1..NB_APP).each do |i|
  NOEUDS << { nom: "app#{i}", ip: "#{RESEAU}.#{20 + i}", mem: 512, role: "app" }
end

# Répartiteur de charge
NOEUDS << { nom: "lb1", ip: "#{RESEAU}.11", mem: 512, role: "lb" }
# ajouter pour faire E1
NOEUDS << { nom: "lb2", ip: "#{RESEAU}.12", mem: 512, role: "lb" }

# Les scripts liront ce fichier dans /vagrant/config/noeuds.yml
FileUtils.mkdir_p("config")
File.write("config/noeuds.yml", NOEUDS.to_yaml)

Vagrant.configure("2") do |config|
  config.vm.box = BOITE
  config.vm.box_version = VERSION

  NOEUDS.each do |n|
    config.vm.define n[:nom] do |m|
      m.vm.hostname = n[:nom]
      m.vm.network "private_network", ip: n[:ip]
      
      # Port forwarding uniquement pour le load balancer  (E1)
      m.vm.network "forwarded_port", guest: 80, host: 8080 if n[:nom] == "lb1"
      
      m.vm.provider "virtualbox" do |vb|
        vb.memory = n[:mem]
        vb.cpus = 1
      end
      
      # Provisionnement : activer seulement si le script existe
      script_path = "scripts/#{n[:role]}.sh"
      if File.exist?(script_path)
        m.vm.provision "shell", path: script_path
      end
    end
  end
end
