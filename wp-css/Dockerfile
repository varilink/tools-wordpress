FROM perl:5

RUN                                                                            \
  cpanm --notest                                                               \
    CSS::Simple                                                                \
    CSS::Tidy                                                                  \
    Data::Walk                                                                 \
    File::Find                                                                 \
    File::Slurp                                                                \
    JSON                                                                       \
    Ref::Util                                                                  \
    Scalar::Util

COPY ./app.pl /usr/src/
WORKDIR /usr/src/

CMD [ "perl", "./app.pl" ]
