const keys = require('./keys');

// EXPRESS APP SETUP
const express = require('express');
const bodyParser = require('body-parser');
const cors = require('cors');

const app = express();
app.use(cors());
app.use(bodyParser.json());

// POSTGRES CLIENT SETUP
const { Pool } = require('pg');
const pgClient = new Pool({
  user: keys.pgUser,
  password: keys.pgPassword,
  host: keys.pgHost,
  database: keys.pgDatabase,
  port: keys.pgPort
});
pgClient.on('error', () => console.log('Lost PG connection'))
pgClient
  .query('CREATE TABLE If NOT EXISTS values (number INT)')
  .catch(err => console.log('err'));

// REDIS CLIENT SETUP
const redis = require('redis');
const redisClient = redis.createClient({
  host: keys.redisHost,
  port: keys.redisPort,
  retry_strategy: () => 1000
});
// мы делаем дубли клиентов тк, согласно документации к библиотеке, нельзя
// пользовать клиент для publish/subscribe еще и для чтения/записи.
// надо иметь разные и для того и для того
const redisPublisher = redisClient.duplicate();

// EXPRESS ROUTES SETUP
app.get('/', (req, res) => {
  res.send('Hi');
});
app.get('/values/all', async (req, res) => {
  const values = await pgClient.query('SELECT * FROM values')
  res.send(values.rows);
});
app.get('/values/current', async (req, res) => {
  // мы пользуем колбэк от редиса тк он не поддерживает поддержки Promise, а то есть и конструкции await
  redisClient.hgetall('values', (err, values) => {
    res.send(values);
  });
});
app.post('/values', async (req, res) => {
  const index = req.body.index;
  if (parseInt(index) > 40) {
    return res.status(422).send('Index too high');
  }
  redisClient.hset('values', index, 'Nothing yet!');
  redisPublisher.publish('insert', index);
  pgClient.query('INSERT INTO values(number) VALUES($1)', [index]);
  res.send({ working: true });
});

app.listen(5000,  err => {
  console.log('listening');
});
