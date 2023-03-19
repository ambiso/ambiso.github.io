+++
title = "Bitwarden PINs can be brute-forced"
[taxonomies]
categories = ["crypto"]
+++

<div style="margin: 0 1% 0 1%; border-radius: 10px; border-bottom-left-radius: 0; border-bottom-right-radius: 0; background-color: #9f3f3f; color: white; padding: 0.5em 0.5em 0.25em; font-weight: bold;">Update</div>
<div style="margin: 0 1% 1em 1%; border-radius: 10px; border-top-left-radius: 0; border-top-right-radius: 0; background-color: #111; padding: 0.25em 0.5em 0.5em;">
Since the writing of this post Bitwarden has updated their <a href="https://bitwarden.com/help/unlock-with-pin/">documentation about the PIN feature</a>:

It now warns rather prominently:
> Using a PIN can weaken the level of encryption that protects your application's local vault database. If you are worried about attack vectors that involve your device's local data being compromised, you may want to reconsider the convenience of using a PIN.

You can view the previous versions <a href="https://web.archive.org/web/20230124121851/https://bitwarden.com/help/unlock-with-pin/">here</a>. The warning seems to exist since September 2022, but back then it was buried at the very bottom of the page.

Unfortunately I could not find any changes to the client (as of 2023-03-19), that would warn a user about this (with e.g. a modal warning), as they're setting the feature up. Maybe I should just submit a PR myself.

I also don't know if any of this applies to the Windows or MacOS clients, you may test it for yourself.

Also don't freak out about this too much, Bitwarden is (as far as I can tell) a good password manager, and you should definitely continue to use it; I just wish they'd warn about the risks of using the PIN feature more clearly.
</div>

<div style="margin: 0 1% 0 1%; border-radius: 10px; border-bottom-left-radius: 0; border-bottom-right-radius: 0; background-color: #3f3f3f; color: white; padding: 0.5em 0.5em 0.25em; font-weight: bold;">Abstract</div>
<div style="margin: 0 1% 1em 1%; border-radius: 10px; border-top-left-radius: 0; border-top-right-radius: 0; background-color: #111; padding: 0.25em 0.5em 0.5em;">
If an attacker can get access to the encrypted vault data stored locally on your device,
and you've configured a Bitwarden PIN as in the image below, the attacker can brute-force the PIN and gain access to your vault's master key.

Effectively, Bitwarden may just as well store the data in plain text on disk.

Bitwarden does not warn about this risk.
</div>

The Bitwarden desktop client and browser extensions allow the user to unlock Bitwarden with a PIN.
This PIN can be set-up per device after logging in to an account using the master password. 
All information pertaining to the PIN is stored locally on the device.
It cannot be used to sign in to an account (read: authenticate with the Bitwarden backend server), but it can be used to obtain access to the vault data, that has been synced and stored locally in encrypted form.

Let's now assume that the user enables the PIN unlock and configures Bitwarden so that it doesn't require the master password on restart.

<div style="display: flex; width: 100%; justify-content: space-around;">
<img src="pin_config.webp" alt="PIN Config Window with a low-entropy PIN entered into the PIN field and the 'Lock with master password on restart' option unchecked" style="width: 20em; margin-top: 1em; margin-bottom: 1em;"/>
</div>

Then a secret derived only from the user's email and PIN will be used to encrypt the master vault key.
It stores roughly

\\[c = \mathrm{Encrypt}_{\mathcal{K}(\mathrm{email},\ \mathrm{PIN})}(\text{master key})\\] 

on disk, where \\(\mathcal{K}\\) is a key derivation function.
This means if an attacker can at any point gain access to the encrypted vault data stored on the device the attacker can brute-force the PIN:
the attacker can check whether decryption of \\(c\\) succeeds using the guessed PIN.
This brute-force will very likely be successful, since PINs are usually very low-entropy.
Now, granted, the key derivation function is PBKDF2 with 100000 iterations (+ HKDF), but that won't help with a 4 digit pin.

Bitwarden seems to be aware that PINs are low-entropy and that many PIN guesses are a problem: the client allows only 5 PIN unlock attempts.
However this 5 guesses limit is enforced completely within the client's logic: it relies on the attacker using the official Bitwarden client.
Instead, an attacker can directly attack the ciphertext \\(c\\) above, trying different PINs until the ciphertext successfully decrypts.

# Exploitation

<video width="100%" controls>
<source src="exploit_demo.webm" type="video/webm">
<meta itemprop="description" content="Video showing bitwarden. User then sets the pin 2345. The vault is locked and then bitwarden is quit. In the terminal the exploit program is run, which after a short while outputs the PIN 2345.">
</video>

A proof of concept exploit for Linux only can be found [here](https://github.com/ambiso/bitwarden-pin).
It uses the fact that the encryption is authenticated and checks whether the MAC verifies using the key derived from the guessed PIN.
It only tests the PINs 0000 through 9999, so you will have to use one of those if you want it to succeed.
Make sure to uncheck the "Lock with master password on restart" option (otherwise the required information would need to be read from the Bitwarden application's memory (quite a different attack scenario)).

It finds any 4 digit PIN in less than 4 seconds:

```
$ time ./target/release/bitwarden-pin
Testing 4 digit pins from 0000 to 9999
Pin found: 9999
./bitwarden-pin  81.73s user 0.03s system 2384% cpu 3.429 total
```

## Bitwarden's response

I've reported the issue to Bitwarden previously, however it was marked out of scope as it belongs to one of these categories:

> Attacks requiring physical access to a user's device

or

> Scenarios that are extremely complex, difficult or unlikely when utilizing already compromised administrative accounts, self-hosted server, networks or physical devices which would render much easier and alternate means of compromising the data contained within Bitwarden

This is however not entirely true: only the device-local encrypted vault data needs to be accessed.
__If accessing device-local data is outside of the threat model, why are we encrypting these data at all? We might as well store them in plain text.__

# Mitigation and Remediation

## 1. Inform better about the risk 

The risk of this attack is relatively low (depending on your threat model): the attacker needs to gain access to the encrypted vault data stored on the device, and the user must configure Bitwarden in a specific way for the attack to be possible.
Dumpster diving could give access to these data when the disk has not been erased and no additional measures like full-disk encryption were taken.
However, if someone gains access to the device data (e.g. through coercion) they can start a brute-force attack, and don't require you to ever enter the PIN/trust the device.

Advantages:
- Nothing to implement

Disadvantage:
- PIN is brute-forceable when device data is obtained

## 2. Rely on a third-party to enforce an unlock attempt limit

Secret-share the master key with a backend that enforces an unlock attempt limit.

Advantages: 
- Easy to implement

Disadvantages:
- Client needs to be online
- Access to the backend database and device allows immediate decryption (without a brute-force attack), the backend may also be coerced into releasing the ciphertext

## 3. Rely on some hardware security magic

Do the above (no. 2) in a Trusted Execution Environment, Intel SGX or something alike.

Advantages:
- Would likely work offline

Disadvantages:
- Not all platforms support hardware security magic

# Final Words

Using a long passphrase as a PIN in bitwarden is safe today. However, Bitwarden takes little effort in communicating the risks of choosing a short low-entropy PIN.
Currently there is very little information to be found about the PIN in Bitwarden documentation, and it is not mentioned in the Security Whitepaper.
A motivated attacker (e.g. a dumpster diver) can recover entire Bitwarden vaults today, unless additional measures like full-disk encryption were taken.

# Sources
