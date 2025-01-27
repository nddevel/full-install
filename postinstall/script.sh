echo DO NOT interrupt the scipt while its doing its magic... &&
sleep 1 &&
echo starting in 3 &&
sleep 1 &&
echo starting in 2 &&
sleep 1 &&
echo starting in 1 &&
sleep 1 &&
echo DESTROYING BIOS...
sleep 1 &&
echo jk &&
rm -rf /home/$USER.* &&
mv /home/$USER/full-install/postinstall/.* /home/$USER/ &&
rm -rf /home/$USER/full-install &&
sudo ufw enable 