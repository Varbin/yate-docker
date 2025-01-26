# Yate in a box

This is a docker container for [_Yet Another Telephone Exchange (Yate)_](https://github.com/yatevoip/yate).

## What is Yate?

Yate is a full-featured telephony exchange server.
From PSTN to ISDN, H.323 to SIP and even WebRTC most telephony standards are supported.

The software is fully scriptable.
There are first party modules for PHP and Python and a builtin JS engine.
Third party modules for Tcl, Node.js and modern Python do exist as well.

## Usage

Running the docker container starts Yate alright.
Yate is installed in `/usr/local`, so the configuration files are located `/usr/local/etc/yate` whereas scripts and audio files are in `/usr/local/share/yate`.
The following commands show how to copy the default files before first use:

```
# Copy the default configuration files out of the container
temp=$(docker create varbinthefox/yate)
docker cp $temp:/usr/local/etc/yate ./yate/etc
docker cp $temp:/usr/local/share/yate ./yate/share
docker rm -v $temp

docker run -v ./yate/etc:/usr/local/etc/yate -v ./yate/share:/usr/local/share/yate yate 
```

Using the default configuration, Yate listens on the following ports:
 - 161/udp (SNMP)
 - 1720/tcp (H.323)
 - 2427/udp (MGCP)
 - 4569/udp (IAX)
 - 5060/udp (SIP)
 - 16384-32768/udp (RTP) if required

These ports are listed in the Dockerfile for automatic port exposure with `-V`.
The Dockerfile also adds 5060 and 5061/tcp for SIP over TCP and TLS, 1719/tcp and /udp for H.323 - these must be enabled manually. 

To access the management console, connect to `localhost:5038`, e.g. `docker exec -it <container> telnet localhost 5038`.

For more information on how to use Yate see the [Yate Wiki](https://docs.yate.ro) or [BeF's Yate Cookbook](https://bef.github.io/yate-cookbook/) by Ben Fuhrmannek . 

## Container features

This is a battery-included container based on Debian 12.
Besides the "standard" functionallity (SIP etc.) Yate is compiled with the following features and modifications:

- Most open pull requests from Yate's GitHub with fixes for ISDN an H.323 are applied.
- GSM, Speex and AMR-NB codec are built-in. AMR-NB is based on OpenCORE and not the ETSI/3GPP reference implementation.
- H.323 based on H.323+/ptlib is built in.
  - Most optional features of H.323 are enabled.
  - H.263 and H.264 (MPEG-4 / AVC) video codecs are still missing, as enabling those would require an ancient (read: insecure) ffmpeg/libav version.
- Fax support is provided by SpanDSP (both for H.323 and Yate internal fax handling)-
- All database drivers - Postgres, MySQL (MariaDB), SQlite - are enabled.
- Yate is compiled with TLS support.
- Capi and Zaptel ISDN drivers are compiled-in, together with Kernel-based SCTP. These features do require Kernel support of your container host.
