// Public client settings. The anon key is safe to ship: every table is protected by row level security.
const supabaseUrl = 'https://onrjdddcutnmbmicfjcu.supabase.co';
const supabaseAnonKey =
    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im9ucmpkZGRjdXRubWJtaWNmamN1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3OTQzMjIzMDgsImV4cCI6MjEwOTg5ODMwOH0.fhbC8FEMil307JmcS8fkkf_hmZVyPkzEB1DqRJd2IYg';

/// Accounts sign in with their Bahrain phone number. Until an SMS provider is
/// connected, the phone maps to an internal e-mail and the user sets a password.
String emailForPhone(String phone) => '$phone@phone.dhabaeh.app';
