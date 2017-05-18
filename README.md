# **Asterisk for ACE Direct Project**

This repository is to be used in conjunction with the documentation for the ACE Direct project (found on the project's [main page](https://github.com/FCC/ACEDirect/tree/master/docs)). The two directories contain configuration files for Asterisk, as well as the media files used for this version of Asterisk.

## Prerequisites

The Asterisk for ACE Direct configuration assumes the following:

* The Asterisk server has a public and local IP address
* A "dial-in" number which has been registered in iTRS and/or a SIP trunk provider (such as Twilio)
* An SSL cert file, acquired from a trusted certificate authority, for the domain of your server. This is necessary for WebRTC functionality as major browsers will drop connections to the Asterisk server if it's cert is not trusted.

## Download/Configure

Once Asterisk and PJSIP has been installed on a server, pull down the repo and switch to the 'AD' branch:


```sh

$ git clone <asterisk_repo_URL>
$ cd asterisk
$ git checkout AD

```

Then modify the following elements in the following files:

* pjsip.conf:
    * <public_ip>: The external.public IP address of the Asterisk server
    * <local_ip>: The private/local IP address of the Asterisk
	* <ss_crt>: Self-signed cert file for server (follow [these instructions](https://wiki.asterisk.org/wiki/display/AST/Secure+Calling+Tutorial) to create a self-signed cert for Asterisk)
	* <ss_ca_crt>: The CA file used to generate the above self-signed cert
* extensions.conf:
	* <dial_in>: Dial-in number
* http.conf & pjsip.conf:
    * <crt_file>: SSL certificate for Asterick server
    * <crt_key>: Private key for Asterisk server 
* rtp.conf:
	* <stun_server>: STUN/TURN server address:port (we recommend building a dedicated STUN server, but a public STUN server can be used if desired)
    
Once the values have been modified, move the files over to /etc/asterisk:

```sh

$ cd asterisk-configs
$ cp -rf * /etc/asterisk

```

Then, move the media files into /var/lib/asterisk/sounds:

```sh

$ cd ../asterisk-videos-audios/sounds
$ cp -rf * /var/lib/asterisk/sounds

```

Finally, restart Asterisk:

```sh

$ service asterisk restart

```

## Modules
Some Asterisk modules have been enabled/disabled in the modules.conf file. Notable modules include:

* res_http_websocket.so: preloaded so that WebSocket connections for WebRTC will work
* res_musiconhold.so: loaded for music-on-hold capability for queues
* res_pjsip.so: loaded so PJSIP stack can be used
* chan_skinny.so: Skinny protocol for Cisco phones. Disabled because this causes Asterisk to listen to TCP connections on port 2000
* cel_pgsq.so: It appears that Asterisk v.14.4.0 trues to connect to PostgreSQL by default, and would cause error messages to be logged to the Asterisk console. Since ACE DIrect uses MySQL, this module has been disbaled.
* chan_sip.so: disabled so PJSIP stack can be used

If you want/need any of these modules, feel free to modify the modules.conf file.

## Automation

There is a script in this repo, within the 'scripts' directory, that will automate the installation of PJSIP and Asterisk, as well as 
pull down the configs and media files from this repo and move them to the appropriate locations.  View the README in the 'scripts'
directory for more information.

