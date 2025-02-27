# This Source Code Form is subject to the terms of the Mozilla Public
# License, v. 2.0. If a copy of the MPL was not distributed with this
# file, You can obtain one at http://mozilla.org/MPL/2.0/.
#
# Copyright (c) 2015-2019 Alexander Williams, Unscramble <license@unscramble.jp>

[de get-sha256 (String Key)
  # works around output diff between openssl 0.9.8 and 1.0.x
  (pipe (out (trim (list 'openssl "dgst" "-sha256" (when Key "-hmac") Key)) (prin String))
        (pack (last (split (chop (line T)) " ") ]

[de get-http-method ()
  (if *Post
      "POST"
      "GET" ]

# Chop the end of the requested URL
[de get-http-url ()
  (glue "/" (head -1 (mapcar pack (split (chop *Url) "/") ]

[de validate-first-run ()
  (when (= 'true (is-first-run?))
        (audit-log "web" "admin" "token.firstrun.failed" (get-http-url))
        (http-msg 403 "Authentication error")
        (bye) ]

[de validate-hash (Hash)
  (let (Path      (pack *Admin_path "etc/api.token")
        Tokenhash     (when (num? (car (info Path))) (in Path (line T)))
        Hmac      (when Tokenhash (get-sha256 (pack (get-http-method) "/" (get-http-url)) Tokenhash)) )

    (when Hmac (= Hash Hmac)) ]

[de validate-token (Token)
  (let (Path (pack *Admin_path "etc/api.token")
       Tokenhash (get-sha256 Token))
    (when (and Tokenhash (num? (car (info Path))))
      (= Tokenhash (in Path (line T) ]

[de validate-auth ()
  (let (Hash  (get 'hash 'http)
        Token (get 'token 'http) )
    (if Hash
        (validate-hash Hash)
        (validate-token Token) ]

[de call-strength-validation (Value)
  (prog
    (sys "NEW_TOKEN" Value)
    (call (pack "/usr/local/share/jidoteki-admin-api/password-validator/validate_token_strength.sh"))]

[de validate-password-strength (Value)
  (if (call-strength-validation Value)
      NIL
      (http-msg 400 (pack "Password is too weak."))) ]

[de update-token (Token)
  (or (validate-string-range Token 'newtoken *Ascii_codes_printable (8 . 255))
      (validate-password-strength Token 'newtoken)
      (let Tokenhash (get-sha256 Token)
      (prog
        (out (pack *Upload_path "api.token") (prinl Tokenhash))
        (sys "SSH_ORIGINAL_COMMAND" "token")
        (call (pack *Admin_path "bin/wrapper.sh")) ]

[de audit-log (Location User Action Target)
 (let (Date (in (list 'date (pack "+%s.%N")) (pack (till "^J")))
       Hash (in (list 'openssl "rand" "-hex" 8) (pack (till "^J"))) )

   (out (pack "+" *Audit_log) (prinl (glue "," (list Date Hash Location User Action (pack "\"" Target "\"") ]

# returns 403 if authentication failed
# returns 400 if "GET" and "POST" methods are reversed
# returns NIL otherwise

(de check-auth-request (Method)
 (validate-first-run)
 (if (validate-auth)
     (case Method
       ("GET"  (when   *Post (http-msg 400 "Invalid authentication method. Expected GET") (bye)))
       ("POST" (unless *Post (http-msg 400 "Invalid authentication method. Expected POST") (bye))) )
     (audit-log "web" "admin" "token.authenticate.failed" (get-http-url))
     (http-msg 403 "Authentication error")
     (bye) ) )

[de check-auth (Method)
 (check-auth-request Method)
 (case Method
   ("GET"  (api-request-get))
   ("POST" (api-request-post)) ]

[de make-random-passphrase (N)
  (in (list '/usr/local/bin/shuf "-n" N *JIDO_WORDLIST) (make (do N (read) (link (read) ]
