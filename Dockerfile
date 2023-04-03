# --- Stage 1: build Meteor app and install its NPM dependencies ---

# Make sure both this and the FROM line further down match the
# version of Node expected by your version of Meteor -- see https://docs.meteor.com/changelog.html
FROM node:14.21.2-alpine3.16 as builder

# APP_SRC_FOLDER is path the your app code relative to this Dockerfile
# /opt/src is where app code is copied into the container
# /opt/app is where app code is built within the container
ENV METEOR_VERSION=2.9.1 \
    APP_SRC_FOLDER=.

RUN echo "\n[*] Installing Meteor ${METEOR_VERSION} to ${HOME}"\
&& curl https://install.meteor.com/?release=${METEOR_VERSION} | /bin/sh

RUN mkdir -p /opt/app /opt/src

WORKDIR /opt/src

COPY ./apps/meteor .

RUN echo '\n[*] Building Meteor bundle' \
&& yarn build:ci --directory /opt/app/bundle

# --- Stage 2: install server dependencies and run Node server ---

FROM node:14.21.2-alpine3.16 as runner

ENV METEOR_VERSION=2.9.1

RUN apk add --no-cache ttf-dejavu

RUN echo "\n[*] Installing Meteor ${METEOR_VERSION} to ${HOME}"\
&& curl https://install.meteor.com/?release=${METEOR_VERSION} | /bin/sh

COPY --from=builder /opt/app/bundle /opt/app/

LABEL maintainer="buildmaster@rocket.chat"

RUN set -x \
    && apk add --no-cache --virtual .fetch-deps python3 make g++ libc6-compat \
    && cd cd /opt/app/programs/server/ \
    && npm install --production \
    # Start hack for sharp...
    && rm -rf npm/node_modules/sharp \
    && npm install sharp@0.30.4 \
    && mv node_modules/sharp npm/node_modules/sharp \
    # End hack for sharp
    && cd npm \
    && npm rebuild bcrypt --build-from-source \
    && npm cache clear --force \
    && apk del .fetch-deps

# needs a mongo instance - defaults to container linking with alias 'mongo'
ENV DEPLOY_METHOD=docker \
    NODE_ENV=production \
    MONGO_URL=mongodb://mongo:27017/rocketchat \
    HOME=/tmp \
    PORT=3000 \
    ROOT_URL=http://localhost:3000 \
    Accounts_AvatarStorePath=/app/uploads

VOLUME /opt/app/uploads

WORKDIR /opt/app/

EXPOSE 3000

CMD ["node", "main.js"]
