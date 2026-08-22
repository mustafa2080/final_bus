const path = require('path');
const k = require(path.join(__dirname, '..', 'serviceAccountKey.json'));
console.log('project_id:', k.project_id);
console.log('client_email:', k.client_email);
console.log('key_len:', k.private_key.length);
console.log('key_starts:', k.private_key.substring(0, 30));
console.log('key_ends:', k.private_key.substring(k.private_key.length - 30));
