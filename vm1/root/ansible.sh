/bin/bash
sudo mkdir -p /home/deploy/.ssh
sudo chmod 700 /home/deploy/.ssh
sudo bash -c 'echo "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJHvfmb84uAiVL0qgosBGyez96zMjCsWl/prFVOzTGt0 technova-ansible@srv-auto.technova.local" >> /home/deploy/.ssh/authorized_keys'
sudo chown -R deploy:deploy /home/deploy/.ssh
sudo chmod 600 /home/deploy/.ssh/authorized_keys
