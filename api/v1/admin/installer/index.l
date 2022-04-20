# Copyright (c) 2022 LogicVein

[de installer-type ()
  (in (list 'cat (pack "/data/installer-type")) (pack (till "^J") ]

[de api-request-get ()
  (if (installer-type)
      (response-json (encode (list (cons "installer" @))))
      (http-msg 404) ]

(check-auth "GET")
