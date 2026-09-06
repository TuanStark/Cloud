FROM node:18

WORKDIR /app

COPY app/backend/ .

RUN npm install


EXPOSE 5000

CMD ["node", "server.js"]
