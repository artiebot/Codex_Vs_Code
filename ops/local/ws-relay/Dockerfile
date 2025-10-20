FROM node:18-alpine

WORKDIR /usr/src/app

COPY package*.json ./
RUN npm install

COPY src ./src

EXPOSE 8081
CMD ["npm", "start"]
