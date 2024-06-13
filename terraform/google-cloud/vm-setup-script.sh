sudo apt update && sudo apt install -y locales htop apt-transport-https software-properties-common
curl -sSL https://apt.ansible.com/ansible-core.gpg | sudo apt-key add -
echo "deb https://apt.ansible.com/focal stable main" | sudo tee /etc/apt/sources.list.d/ansible.list
sudo apt update && sudo apt install -y ansible git

git clone https://github.com/openpreserve/ViPER.git ~/ViPER
ansible-playbook ~/ViPER/ansible/initialise-env.yml