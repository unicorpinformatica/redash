FROM alpine:3.18 as frontend-version-fixed

WORKDIR /frontend

RUN apk add --no-cache jq

COPY package.json package-lock.json ./

RUN jq '.version = "10.1.0"' package.json > package.json.tmp && mv package.json.tmp package.json
RUN jq '.version = "10.1.0"' package-lock.json > package-lock.json.tmp && mv package-lock.json.tmp package-lock.json

FROM node:12 as frontend-builder

# Controls whether to build the frontend assets
ARG skip_frontend_build

ENV CYPRESS_INSTALL_BINARY=0
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=1

RUN useradd -m -d /frontend redash
USER redash

WORKDIR /frontend
COPY --from=frontend-version-fixed --chown=redash /frontend/package.json  /frontend/package-lock.json /frontend/
COPY --chown=redash viz-lib /frontend/viz-lib

# Controls whether to instrument code for coverage information
ARG code_coverage
ENV BABEL_ENV=${code_coverage:+test}

RUN if [ "x$skip_frontend_build" = "x" ] ; then npm ci --unsafe-perm; fi

COPY --chown=redash package.json package-lock.json /frontend/
COPY --chown=redash client /frontend/client
COPY --chown=redash webpack.config.js /frontend/
RUN if [ "x$skip_frontend_build" = "x" ] ; then npm run build; else mkdir -p /frontend/client/dist && touch /frontend/client/dist/multi_org.html && touch /frontend/client/dist/index.html; fi

FROM python:3.7-slim-buster

EXPOSE 5000

# Controls whether to install extra dependencies needed for all data sources.
ARG skip_ds_deps
# Controls whether to install dev dependencies.
ARG skip_dev_deps

RUN useradd --create-home redash

# Ubuntu packages
RUN apt-get update && \
  apt-get install -y \
    curl \
    gnupg \
    build-essential \
    pwgen \
    libffi-dev \
    sudo \
    git-core \
    wget \
    # Postgres client
    libpq-dev \
    # ODBC support:
    g++ unixodbc-dev \
    # for SAML
    xmlsec1 \
    # Additional packages required for data sources:
    libssl-dev \
    default-libmysqlclient-dev \
    freetds-dev \
    libsasl2-dev \
    unzip \
    libsasl2-modules-gssapi-mit && \
  # MSSQL ODBC Driver:  
  curl https://packages.microsoft.com/keys/microsoft.asc | apt-key add - && \
  curl https://packages.microsoft.com/config/debian/10/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
  apt-get update && \
  ACCEPT_EULA=Y apt-get install -y msodbcsql17 && \
  apt-get clean && \
  rm -rf /var/lib/apt/lists/*

ARG databricks_odbc_driver_url=https://databricks.com/wp-content/uploads/2.6.10.1010-2/SimbaSparkODBC-2.6.10.1010-2-Debian-64bit.zip
RUN wget --quiet $databricks_odbc_driver_url -O /tmp/simba_odbc.zip \
  && chmod 600 /tmp/simba_odbc.zip \
  && unzip /tmp/simba_odbc.zip -d /tmp/ \
  && dpkg -i /tmp/SimbaSparkODBC-*/*.deb \
  && echo "[Simba]\nDriver = /opt/simba/spark/lib/64/libsparkodbc_sb64.so" >> /etc/odbcinst.ini \
  && rm /tmp/simba_odbc.zip \
  && rm -rf /tmp/SimbaSparkODBC*

WORKDIR /app

# Disalbe PIP Cache and Version Check
ENV PIP_DISABLE_PIP_VERSION_CHECK=1
ENV PIP_NO_CACHE_DIR=1

# rollback pip version to avoid legacy resolver problem
RUN pip install pip==20.2.4;

# We first copy only the requirements file, to avoid rebuilding on every file change.
# COPY requirements_all_ds.txt ./
# RUN if [ "x$skip_ds_deps" = "x" ] ; then pip install -r requirements_all_ds.txt ; else echo "Skipping pip install -r requirements_all_ds.txt" ; fi

# COPY requirements_bundles.txt requirements_dev.txt ./
# RUN if [ "x$skip_dev_deps" = "x" ] ; then pip install -r requirements_dev.txt ; fi

# COPY requirements.txt ./
# RUN pip install -r requirements.txt

# Adiciona o Oracle Instant Client
RUN apt-get update && apt-get install -y libaio1 wget unzip
RUN mkdir /opt/oracle
WORKDIR /opt/oracle
RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/instantclient-basic-linux.x64-19.6.0.0.0dbru.zip \
&& unzip instantclient-basic-linux.x64-19.6.0.0.0dbru.zip \
&& rm -f instantclient-basic-linux.x64-19.6.0.0.0dbru.zip 

RUN wget https://download.oracle.com/otn_software/linux/instantclient/19600/\instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip \
&& unzip \instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip \
&& rm -f \instantclient-sdk-linux.x64-19.6.0.0.0dbru.zip 

WORKDIR /opt/oracle/instantclient_19_6
RUN rm -f *jdbc* *occi* *mysql* *README *jar uidrvci genezi adrci 
RUN echo /opt/oracle/instantclient_19_6 > /etc/ld.so.conf.d/oracle-instantclient.conf \
&& ldconfig

# Adiciona a variável de ambiente REDASH para adicionar o Oracle Query Runner
ENV ORACLE_HOME=/opt/oracle/instantclient_19_6
ENV LD_LIBRARY_PATH=$LD_LIBRARY_PATH:/opt/oracle/instantclient_19_6

# Add REDASH ENV to add Oracle Query Runner
ENV REDASH_ADDITIONAL_QUERY_RUNNERS=redash.query_runner.oracle
# End add Oracle Instant Client

COPY requirements_hotfix.txt ./
RUN pip install -r requirements_hotfix.txt

WORKDIR /app
COPY . /app
COPY --from=frontend-builder /frontend/client/dist /app/client/dist
RUN chown -R redash /app



WORKDIR /app

USER redash

ENTRYPOINT ["/app/bin/docker-entrypoint"]
CMD ["server"]