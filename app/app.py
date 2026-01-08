import os
import sqlite3
import subprocess
from flask import Flask, request, render_template, redirect, url_for, session, g

app = Flask(__name__)
app.secret_key = 'super_secret_key_change_this_in_prod'
DATABASE = 'database.db'

def get_db():
    db = getattr(g, '_database', None)
    if db is None:
        db = g._database = sqlite3.connect(DATABASE)
    return db

@app.teardown_appcontext
def close_connection(exception):
    db = getattr(g, '_database', None)
    if db is not None:
        db.close()

def init_db():
    with app.app_context():
        db = get_db()
        cursor = db.cursor()
        cursor.execute('''CREATE TABLE IF NOT EXISTS users (id INTEGER PRIMARY KEY, username TEXT, password TEXT)''')
        # Insert admin user
        cursor.execute("INSERT OR IGNORE INTO users (id, username, password) VALUES (1, 'admin', 'admin123')")
        db.commit()

@app.route('/')
def index():
    if 'user_id' in session:
        return redirect(url_for('dashboard'))
    return render_template('login.html')

@app.route('/login', methods=['GET', 'POST'])
def login():
    error = None
    if request.method == 'POST':
        username = request.form['username']
        password = request.form['password']
        
        # VULNERABILITY: SQL Injection
        conn = get_db()
        cursor = conn.cursor()
        query = f"SELECT * FROM users WHERE username = '{username}' AND password = '{password}'"
        try:
            cursor.execute(query)
            user = cursor.fetchone()
            
            if user:
                session['user_id'] = user[0]
                session['username'] = user[1]
                return redirect(url_for('dashboard'))
            else:
                error = 'Invalid Credentials'
        except Exception as e:
             error = f"Database Error: {str(e)}" # Leaking error helps with SQLi exploitation locally

    return render_template('login.html', error=error)

@app.route('/dashboard')
def dashboard():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    return render_template('dashboard.html', username=session['username'])

@app.route('/tools', methods=['GET', 'POST'])
def tools():
    if 'user_id' not in session:
        return redirect(url_for('login'))
    
    output = ""
    if request.method == 'POST':
        target = request.form.get('target', '')
        # VULNERABILITY: Command Injection
        # The user input 'target' is passed directly to the shell
        if target:
            try:
                # Intentionally using shell=True and not sanitizing input
                output = subprocess.check_output(f"ping -c 1 {target}", shell=True, stderr=subprocess.STDOUT)
                output = output.decode('utf-8')
            except subprocess.CalledProcessError as e:
                output = e.output.decode('utf-8')
            except Exception as e:
                output = str(e)
                
    return render_template('tools.html', output=output)

@app.route('/logout')
def logout():
    session.pop('user_id', None)
    return redirect(url_for('index'))

if __name__ == '__main__':
    if not os.path.exists(DATABASE):
        init_db()
    app.run(host='0.0.0.0', port=5000, debug=False)
