const { createClient } = require('@supabase/supabase-js');
const fs = require('fs');

async function test() {
  const supabaseUrl = 'http://127.0.0.1:54321';
  const anonKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZS1kZW1vIiwicm9sZSI6ImFub24iLCJleHAiOjE5ODM4MTI5OTZ9.CRXP1A7WOeoJeXxjNni43kdQwgnWNReilDMblYTn_I0'; // Grabbing from task-9 output above

  const supabase = createClient(supabaseUrl, anonKey);
  const { data, error } = await supabase.auth.signUp({
    email: 'test' + Date.now() + '@example.com',
    password: 'password123'
  });
  console.log("Signup Data:", data);
  console.log("Signup Error:", error);
}
test();
