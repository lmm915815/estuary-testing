#! /bin/sh 
. ../../lib/sh-test-lib 
OUTPUT="$(pwd)/output"
RESULT_FILE="${OUTPUT}/result.txt"
export RESULT_FILE



install(){
    pkgs="samba samba-client"
    install_deps "${pkgs} ${SKIP_INSTALL}"
}
configParament(){
    # backup config file
    cp /etc/samba/smb.conf{,.bak}
    # share config
    cat  >> /etc/samba/smb.conf << EOF
    [share]
        comment = Anonymous share
        path = /srv/samba/share
        public =yes
        browsable = yes
        writable = yes
        guest ok = yes
        read only = no 
EOF

    # create the folder with the name share and give the permission
    mkdir -p /srv/samba/share
    chmod -R 0755 /srv/samba/share/
    chown -R nobody:nobody /srv/samba/share/

    # 2 secured config 
    #2.1 add test user 
    groupadd -f  smbgrp
    ret=`useradd smb -G smbgrp`
    if [$ret == 0]then
    elif [$ret == 9] then
        userdel smb 
        useradd smb -G smbgrp
    else
        echo "useradd error"
    fi

    smbpasswd -a smb -s << EOF
    smbpw 
    smbpw 
EOF
    mkdir -p /srv/samba/secured
    chmod -R 0755 /srv/samba/secured
    chown -R smb:smbgrp /srv/samba/secured

    cat >> /etc/samba/smb.conf << EOF
    [secured]
        commant = secured share
        path = /srv/samba/secured
        valid users = @smbgrp
        guest ok = no
        writable = yes
        browsable = yes
EOF

    

    # restart samba service
    systemctl enable smb.service
    systemctl restart smb.service

    # close firewall
    systemctl stop firewall.service

    testparm -s
    if [$? -ne 0] then
        echo "config has some error"
        exit
    fi

}
run(){
    smbclient //localhost/share -U user -N -c "ls" 
    check_return "smbclient-share-anonymous" 

    smbclient //localhost/share -U smb%smbpw -c "ls"
    check_return "smbclient-share-named"

    smbclient //localhost/secured -U smb%smbpw -c "ls"
    check_return "smbclient-secured-named"

}

create_out_dir "${OUTPUT}"

install 

configParament

run

