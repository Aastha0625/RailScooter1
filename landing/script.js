// Initialize Supabase Client
// Credentials sourced from the main.dart file in the flutter app
const supabaseUrl = 'https://efyhhqeshzvhjbjrbkza.supabase.co';
const supabaseKey = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImVmeWhocWVzaHp2aGpianJia3phIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODA3MjQyMTgsImV4cCI6MjA5NjMwMDIxOH0.KqP28xGn46TqocKypRbpj_-9AwD4NWd7N65fC1pZNK4';

// Only initialize if supabase client is available (on the login page)
let supabase;
if (window.supabase) {
    supabase = window.supabase.createClient(supabaseUrl, supabaseKey);
}

// RBAC Role Handling Logic
document.addEventListener('DOMContentLoaded', () => {
    const roleTabs = document.querySelectorAll('.role-tab');
    const submitBtn = document.getElementById('submitBtn');
    let selectedRole = 'Admin'; // Default role

    // Handle Tab Clicks
    if (roleTabs.length > 0) {
        roleTabs.forEach(tab => {
            tab.addEventListener('click', (e) => {
                // Remove active class from all
                roleTabs.forEach(t => t.classList.remove('active'));
                
                // Add active class to clicked tab
                e.target.classList.add('active');
                
                // Update selected role state
                selectedRole = e.target.getAttribute('data-role');
                
                // Update button text
                if (submitBtn) {
                    submitBtn.textContent = `Sign In as ${selectedRole}`;
                }
            });
        });
    }

    // Handle Form Submission
    const loginForm = document.getElementById('loginForm');
    const errorAlert = document.getElementById('errorAlert');
    const successAlert = document.getElementById('successAlert');

    if (loginForm) {
        loginForm.addEventListener('submit', async (e) => {
            e.preventDefault();
            
            // Hide previous alerts
            errorAlert.style.display = 'none';
            successAlert.style.display = 'none';

            const email = document.getElementById('email').value.trim();
            const password = document.getElementById('password').value;

            // Set button to loading state
            const originalBtnText = submitBtn.textContent;
            submitBtn.disabled = true;
            submitBtn.innerHTML = '<span class="loader"></span>';

            try {
                // Real API Call to Supabase Auth
                const { data, error } = await supabase.auth.signInWithPassword({
                    email: email,
                    password: password,
                });

                if (error) {
                    throw error;
                }

                // Assuming login is successful:
                // Note: In a full implementation, you would check if the user's role 
                // in your database matches the `selectedRole` they tried to log in as.
                // For example:
                // const { data: profile } = await supabase.from('profiles').select('role').eq('id', data.user.id).single();
                // if (profile.role !== selectedRole.toLowerCase()) throw new Error("Unauthorized role");

                successAlert.textContent = `Successfully logged in as ${selectedRole}! Redirecting...`;
                successAlert.style.display = 'block';

                // Redirect to dashboard or appropriate app scheme after a short delay
                setTimeout(() => {
                    // For the flutter app, this might redirect to a web dashboard 
                    // or trigger a deep link depending on your setup.
                    // window.location.href = '/dashboard.html';
                }, 1500);

            } catch (err) {
                console.error(err);
                errorAlert.textContent = err.message || 'An error occurred during login.';
                errorAlert.style.display = 'block';
            } finally {
                // Restore button state
                submitBtn.disabled = false;
                submitBtn.textContent = originalBtnText;
            }
        });
    }
});
