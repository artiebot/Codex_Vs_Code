FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY src ./src
COPY public ./public

EXPOSE 8090
CMD ["npm", "start"]
