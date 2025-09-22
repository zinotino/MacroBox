#!/usr/bin/env python3
"""
MacroMaster Optimized Analytics Dashboard
9-chart display with relevant information for MacroMaster workflow
"""
import pandas as pd
import plotly.graph_objects as go
import plotly.express as px
from plotly.subplots import make_subplots
import sys
import os
import webbrowser
from datetime import datetime, timedelta
import argparse
import json

class MacroMasterOptimizedAnalytics:
    def __init__(self, csv_path):
        self.csv_path = csv_path
        self.df = self.load_and_clean_data()
        
        # MacroMaster-specific data mappings
        self.degradation_types = {
            'smudge': '💧 Smudge',
            'glare': '☀️ Glare', 
            'splashes': '💦 Splashes',
            'partial_blockage': '🚧 Partial Block',
            'full_blockage': '🚫 Full Block',
            'light_flare': '✨ Light Flare',
            'rain': '🌧️ Rain',
            'haze': '🌫️ Haze',
            'snow': '❄️ Snow',
            'none': '✅ Clean'
        }
        
        self.severity_colors = {
            'high': '#e74c3c',
            'medium': '#f39c12',
            'low': '#27ae60',
            'none': '#3498db'
        }

        # Consistent execution type colors across all charts
        self.execution_type_colors = {
            'macro': '#3498db',        # Blue for macros
            'json_profile': '#e74c3c'  # Red for JSON profiles
        }
        
    def load_and_clean_data(self):
        """Load and optimize MacroMaster CSV data"""
        try:
            # Read CSV with flexible parsing
            df = pd.read_csv(self.csv_path, parse_dates=['timestamp'], on_bad_lines='skip')
            
            if df.empty:
                print("No data found in CSV")
                return pd.DataFrame()
            
            # Keep only rows with essential data
            df = df.dropna(subset=['timestamp', 'execution_type', 'button_key', 'total_boxes', 'execution_time_ms'])
            
            if df.empty:
                print("No valid data found after cleaning")
                return pd.DataFrame()
            
            # Clean data types
            df['execution_time_ms'] = pd.to_numeric(df['execution_time_ms'], errors='coerce')
            df['total_boxes'] = pd.to_numeric(df['total_boxes'], errors='coerce')
            df['layer'] = pd.to_numeric(df['layer'], errors='coerce')
            
            # Fill missing fields
            df['session_id'] = df['session_id'].fillna('unknown_session')
            df['username'] = df['username'].fillna('unknown_user')
            df['degradation_assignments'] = df['degradation_assignments'].fillna('none')
            df['severity_level'] = df['severity_level'].fillna('none')
            df['canvas_mode'] = df['canvas_mode'].fillna('wide')

            # Clean degradation_assignments field (remove quotes and standardize)
            df['degradation_assignments'] = df['degradation_assignments'].astype(str)
            df['degradation_assignments'] = df['degradation_assignments'].str.strip('"\'')  # Remove quotes
            df['degradation_assignments'] = df['degradation_assignments'].str.replace('none', 'clear')  # Standardize
            
            # Add analysis columns
            df['date'] = df['timestamp'].dt.date
            df['hour'] = df['timestamp'].dt.hour
            df['execution_time_s'] = df['execution_time_ms'] / 1000
            df['boxes_per_second'] = df['total_boxes'] / df['execution_time_s']
            df['boxes_per_second'] = df['boxes_per_second'].replace([float('inf'), -float('inf')], 0)
            
            print(f"Loaded {len(df)} MacroMaster execution records")
            return df
            
        except Exception as e:
            print(f"Error loading MacroMaster data: {e}")
            return pd.DataFrame()
    
    def filter_data(self, filter_mode="all", days_back=None):
        """Filter data for analysis"""
        if self.df.empty:
            return self.df
            
        if filter_mode == "today":
            today = datetime.now().date()
            return self.df[self.df['date'] == today]
        elif filter_mode == "session":
            cutoff = datetime.now() - timedelta(hours=8)
            return self.df[self.df['timestamp'] >= cutoff]
        elif filter_mode == "week":
            cutoff = datetime.now() - timedelta(days=7)
            return self.df[self.df['timestamp'] >= cutoff]
        elif days_back:
            cutoff = datetime.now() - timedelta(days=days_back)
            return self.df[self.df['timestamp'] >= cutoff]
        else:
            return self.df
    
    def create_optimized_dashboard(self, filter_mode="all"):
        """Create 9-chart dashboard with relevant MacroMaster information plus text summary"""
        
        # Filter data
        df_filtered = self.filter_data(filter_mode)
        
        if df_filtered.empty:
            self.create_empty_dashboard(filter_mode)
            return
        
        # Create 4x3 grid layout (9 charts + 3 text sections)
        fig = make_subplots(
            rows=4, cols=3,
            subplot_titles=[
                '📊 Execution Timeline', '📈 Execution Types', '📦 Boxes Distribution',
                '⏱️ Execution Speed', '🎮 Button Performance', '📅 Hourly Activity',
                '🎨 All Degradations', '🔵 Macro Degradations', '🔴 JSON Degradations',
                '📈 Session Summary', '💻 Workflow Analysis', '🔍 Performance Insights'
            ],
            specs=[
                [{"secondary_y": False}, {"type": "pie"}, {"type": "histogram"}],
                [{"type": "scatter"}, {"type": "bar"}, {"type": "bar"}],
                [{"type": "pie"}, {"type": "pie"}, {"type": "pie"}],
                [{"type": "table"}, {"type": "table"}, {"type": "table"}]
            ],
            vertical_spacing=0.08,
            horizontal_spacing=0.08,
            row_heights=[0.25, 0.25, 0.25, 0.25]
        )
        
        # Row 1: Timeline & Distribution Charts
        self.add_execution_timeline(fig, df_filtered, row=1, col=1)
        self.add_execution_types(fig, df_filtered, row=1, col=2)
        self.add_boxes_distribution(fig, df_filtered, row=1, col=3)

        # Row 2: Performance & Button Analysis Charts
        self.add_execution_speed_scatter(fig, df_filtered, row=2, col=1)
        self.add_button_performance(fig, df_filtered, row=2, col=2)
        self.add_hourly_activity_chart(fig, df_filtered, row=2, col=3)

        # Row 3: Degradation Analysis Charts
        self.add_degradation_breakdown(fig, df_filtered, row=3, col=1)
        self.add_degradation_pie_macros(fig, df_filtered, row=3, col=2)
        self.add_degradation_pie_json(fig, df_filtered, row=3, col=3)
        
        # Row 4: Text Analysis Section
        self.add_session_summary_table(fig, df_filtered, row=4, col=1)
        self.add_workflow_analysis_table(fig, df_filtered, row=4, col=2)
        self.add_performance_insights_table(fig, df_filtered, row=4, col=3)
        
        # Clean layout
        fig.update_layout(
            title={
                'text': f"🎮 MacroMaster Analytics Dashboard - {filter_mode.title()} View",
                'x': 0.5,
                'xanchor': 'center',
                'font': {'size': 24, 'color': '#2c5aa0'}
            },
            showlegend=False,
            height=1500,
            width=1600,
            template="plotly_white",
            font={'family': 'Arial, sans-serif', 'size': 11},
            margin=dict(l=60, r=60, t=90, b=60)
        )
        
        # Save and display
        output_file = f"macromaster_optimized_{filter_mode}.html"
        fig.write_html(output_file, auto_open=False)
        print(f"MacroMaster Optimized Analytics saved as: {output_file}")

        # Open in browser
        webbrowser.open(f"file://{os.path.abspath(output_file)}")

        # Save metrics
        self.save_optimized_metrics(df_filtered, filter_mode)
    
    def add_execution_timeline(self, fig, df, row, col):
        """Execution timeline with unified colors by execution type"""
        if df.empty:
            return

        # Group by hour and execution type
        hourly_data = df.groupby([df['timestamp'].dt.floor('h'), 'execution_type']).agg({
            'execution_time_ms': 'count',
            'total_boxes': 'sum'
        }).reset_index()

        # Plot each execution type with consistent colors
        for exec_type in hourly_data['execution_type'].unique():
            type_data = hourly_data[hourly_data['execution_type'] == exec_type]
            color = self.execution_type_colors.get(exec_type, '#95a5a6')

            fig.add_trace(
                go.Scatter(
                    x=type_data['timestamp'],
                    y=type_data['execution_time_ms'],
                    mode='lines+markers',
                    name=f'{exec_type.replace("_", " ").title()}',
                    line=dict(color=color, width=3),
                    marker=dict(size=8),
                    hovertemplate=f"<b>%{{x}}</b><br>{exec_type}: %{{y}} executions<extra></extra>"
                ),
                row=row, col=col
            )

        fig.update_xaxes(title_text="Time", row=row, col=col)
        fig.update_yaxes(title_text="Executions by Type", row=row, col=col)
    
    def add_button_performance(self, fig, df, row, col):
        """Button performance ranking - most relevant"""
        if df.empty:
            return
            
        # Group by button key
        button_stats = df.groupby('button_key').agg({
            'total_boxes': 'sum',
            'execution_time_ms': 'count'
        }).reset_index()
        
        button_stats = button_stats.sort_values('total_boxes', ascending=True)
        
        fig.add_trace(
            go.Bar(
                y=button_stats['button_key'],
                x=button_stats['total_boxes'],
                orientation='h',
                name="Button Performance",
                marker_color='#2ecc71',
                text=button_stats['execution_time_ms'],
                texttemplate='%{text} uses',
                textposition='inside',
                hovertemplate="<b>%{y}</b><br>Boxes: %{x}<br>Uses: %{text}<extra></extra>"
            ),
            row=row, col=col
        )
        
        fig.update_xaxes(title_text="Total Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Button", row=row, col=col)
    
    def add_degradation_pie_macros(self, fig, df, row, col):
        """Macro degradation breakdown - separate from JSON"""
        macro_df = df[
            (df['execution_type'] == 'macro') &
            (df['degradation_assignments'].notna()) &
            (df['degradation_assignments'] != 'none') &
            (df['degradation_assignments'] != '')
        ]

        if macro_df.empty:
            return

        degradation_counts = macro_df['degradation_assignments'].value_counts()

        fig.add_trace(
            go.Pie(
                labels=degradation_counts.index,
                values=degradation_counts.values,
                name="Macro Degradations",
                marker_colors=['#3498db', '#5dade2', '#85c1e9', '#aed6f1', '#d6eaf8'],
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>Percentage: %{percent}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_traces(textinfo='label+percent', row=row, col=col)
    
    def add_degradation_breakdown(self, fig, df, row, col):
        """Degradation breakdown - relevant for data quality"""
        # Include both json_profile AND macro executions with degradation data
        degradation_df = df[
            (df['execution_type'].isin(['json_profile', 'macro'])) &
            (df['degradation_assignments'].notna()) &
            (df['degradation_assignments'] != '') &
            (df['degradation_assignments'] != 'clear')
        ].copy()

        if degradation_df.empty:
            # For pie chart subplots, use domain coordinates
            fig.add_annotation(
                text="No Degradation Data<br>All executions marked as clear",
                xref="paper", yref="paper",
                x=0.165, y=0.72,  # Approximate position for row=2, col=1 in pie chart
                showarrow=False,
                font=dict(size=12, color='#7f8c8d'),
                align="center"
            )
            return
        
        # Count degradation types
        degradation_counts = degradation_df['degradation_assignments'].value_counts()
        labels = [self.degradation_types.get(deg, deg) for deg in degradation_counts.index]
        
        # Color by severity
        colors = []
        for deg in degradation_counts.index:
            if deg in ['full_blockage', 'partial_blockage']:
                colors.append(self.severity_colors['high'])
            elif deg in ['glare', 'light_flare', 'rain']:
                colors.append(self.severity_colors['medium'])
            elif deg in ['smudge', 'haze', 'splashes', 'snow']:
                colors.append(self.severity_colors['low'])
            else:
                colors.append(self.severity_colors['none'])
        
        fig.add_trace(
            go.Pie(
                labels=labels,
                values=degradation_counts.values,
                name="Degradation",
                marker_colors=colors,
                hole=0.3,
                textinfo='label+value'
            ),
            row=row, col=col
        )
    
    def add_execution_types(self, fig, df, row, col):
        """Execution type distribution - relevant for workflow balance"""
        if df.empty:
            return
            
        type_counts = df['execution_type'].value_counts()

        # Use consistent execution type colors
        colors = [self.execution_type_colors.get(exec_type, '#95a5a6') for exec_type in type_counts.index]

        fig.add_trace(
            go.Pie(
                labels=[t.title().replace('_', ' ') for t in type_counts.index],
                values=type_counts.values,
                name="Execution Types",
                marker_colors=colors,
                hole=0.3,
                textinfo='label+value+percent'
            ),
            row=row, col=col
        )
    
    def add_boxes_distribution(self, fig, df, row, col):
        """Boxes per execution distribution - relevant for consistency"""
        if df.empty:
            return
            
        fig.add_trace(
            go.Histogram(
                x=df['total_boxes'],
                nbinsx=15,
                name="Boxes Distribution",
                marker_color='#9b59b6',
                opacity=0.7
            ),
            row=row, col=col
        )
        
        fig.update_xaxes(title_text="Boxes per Execution", row=row, col=col)
        fig.update_yaxes(title_text="Frequency", row=row, col=col)
    
    def add_execution_speed_scatter(self, fig, df, row, col):
        """Execution speed analysis - relevant for performance optimization"""
        if df.empty:
            return
            
        # Color by execution type using consistent mapping
        colors = [self.execution_type_colors.get(t, '#95a5a6') for t in df['execution_type']]
        
        fig.add_trace(
            go.Scatter(
                x=df['total_boxes'],
                y=df['execution_time_ms'],
                mode='markers',
                marker=dict(
                    color=colors,
                    size=10,
                    opacity=0.7
                ),
                name="Speed Analysis",
                text=df['execution_type'],
                hovertemplate="<b>Boxes:</b> %{x}<br><b>Time:</b> %{y}ms<br><b>Type:</b> %{text}<extra></extra>"
            ),
            row=row, col=col
        )
        
        fig.update_xaxes(title_text="Boxes", row=row, col=col)
        fig.update_yaxes(title_text="Execution Time (ms)", row=row, col=col)
    
    def add_hourly_activity_chart(self, fig, df, row, col):
        """Hourly activity breakdown - relevant for time management"""
        if df.empty:
            return
            
        # Group by hour of day
        hourly_activity = df.groupby('hour').agg({
            'execution_time_ms': 'count',
            'total_boxes': 'sum'
        }).reset_index()
        
        fig.add_trace(
            go.Bar(
                x=hourly_activity['hour'],
                y=hourly_activity['execution_time_ms'],
                name="Hourly Activity",
                marker_color='#3498db',
                text=hourly_activity['total_boxes'],
                texttemplate='%{text} boxes',
                textposition='outside',
                hovertemplate="<b>Hour:</b> %{x}:00<br><b>Executions:</b> %{y}<br><b>Boxes:</b> %{text}<extra></extra>"
            ),
            row=row, col=col
        )
        
        fig.update_xaxes(title_text="Hour of Day", row=row, col=col)
        fig.update_yaxes(title_text="Executions", row=row, col=col)
    
    def add_degradation_pie_json(self, fig, df, row, col):
        """JSON degradation breakdown - separate from macros"""
        json_df = df[
            (df['execution_type'] == 'json_profile') &
            (df['degradation_assignments'].notna()) &
            (df['degradation_assignments'] != 'none') &
            (df['degradation_assignments'] != '')
        ]

        if json_df.empty:
            return

        degradation_counts = json_df['degradation_assignments'].value_counts()

        fig.add_trace(
            go.Pie(
                labels=degradation_counts.index,
                values=degradation_counts.values,
                name="JSON Degradations",
                marker_colors=['#e74c3c', '#ec7063', '#f1948a', '#f5b7b1', '#fadbd8'],
                hovertemplate="<b>%{label}</b><br>Count: %{value}<br>Percentage: %{percent}<extra></extra>"
            ),
            row=row, col=col
        )

        fig.update_traces(textinfo='label+percent', row=row, col=col)
    
    def add_session_summary_table(self, fig, df, row, col):
        """Session summary - relevant session metrics"""
        if df.empty:
            return
        
        # Calculate session metrics
        total_executions = len(df)
        total_boxes = int(df['total_boxes'].sum())
        macro_count = len(df[df['execution_type'] == 'macro'])
        json_count = len(df[df['execution_type'] == 'json_profile'])
        avg_time = df['execution_time_ms'].mean()
        efficiency = df['boxes_per_second'].mean()
        
        # Session duration
        session_duration = (df['timestamp'].max() - df['timestamp'].min()).total_seconds() / 3600
        
        session_data = {
            'Session Metric': [
                'Total Executions',
                'Macro Executions',
                'JSON Profiles',
                'Total Boxes',
                'Average Time',
                'Efficiency',
                'Session Duration',
                'Boxes/Hour'
            ],
            'Value': [
                f"{total_executions}",
                f"{macro_count}",
                f"{json_count}",
                f"{total_boxes}",
                f"{avg_time:.0f}ms",
                f"{efficiency:.2f} boxes/sec",
                f"{session_duration:.1f}h",
                f"{total_boxes/session_duration:.0f} boxes/hr" if session_duration > 0 else "0 boxes/hr"
            ]
        }
        
        fig.add_trace(
            go.Table(
                header=dict(
                    values=['🎯 Session Summary', '📊 Values'],
                    fill_color='#3498db',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(session_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )
    
    def add_workflow_analysis_table(self, fig, df, row, col):
        """Workflow analysis - relevant insights"""
        if df.empty:
            return
        
        # Calculate workflow insights
        if 'button_key' in df.columns and not df['button_key'].isna().all():
            button_efficiency = df.groupby('button_key')['boxes_per_second'].mean()
            top_button = button_efficiency.idxmax()
            top_efficiency = button_efficiency.max()
        else:
            top_button = 'N/A'
            top_efficiency = 0
        
        # Quality analysis
        json_df = df[df['execution_type'] == 'json_profile']
        quality_score = 100
        if not json_df.empty:
            degraded_count = len(json_df[json_df['degradation_assignments'] != 'none'])
            degradation_rate = (degraded_count / len(json_df)) * 100
            quality_score = 100 - degradation_rate
        
        # Raw numerical data only
        total_executions = len(df)
        total_time_hours = df['execution_time_ms'].sum() / (1000 * 3600)
        avg_boxes_per_exec = df['total_boxes'].mean()
        std_deviation = df['total_boxes'].std()

        workflow_data = {
            'Raw Data': [
                'Most Used Button',
                'Button Rate',
                'Average Boxes per Execution',
                'Total Executions',
                'Total Hours',
                'Boxes/Second Average',
                'Standard Deviation',
                'JSON Executions'
            ],
            'Numbers': [
                f"{top_button}",
                f"{top_efficiency:.2f} boxes/sec",
                f"{avg_boxes_per_exec:.1f}",
                f"{total_executions}",
                f"{total_time_hours:.2f}",
                f"{df['boxes_per_second'].mean():.2f}",
                f"{std_deviation:.1f}",
                f"{len(json_df) if not json_df.empty else 0}"
            ]
        }
        
        fig.add_trace(
            go.Table(
                header=dict(
                    values=['💻 Workflow Analysis', '🎯 Insights'],
                    fill_color='#2ecc71',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(workflow_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'left']
                )
            ),
            row=row, col=col
        )
    
    def add_performance_insights_table(self, fig, df, row, col):
        """Performance insights - data-focused analysis"""
        if df.empty:
            return
        
        # Calculate advanced performance metrics
        total_time_hours = df['execution_time_ms'].sum() / (1000 * 3600)
        total_boxes = int(df['total_boxes'].sum())
        avg_speed = df['boxes_per_second'].mean()
        median_speed = df['boxes_per_second'].median()
        speed_std = df['boxes_per_second'].std()
        
        # Time analysis
        fastest_execution = df['execution_time_ms'].min()
        slowest_execution = df['execution_time_ms'].max()
        avg_execution_time = df['execution_time_ms'].mean()
        
        # Box analysis
        max_boxes_single = int(df['total_boxes'].max())
        avg_boxes = df['total_boxes'].mean()
        
        # Quality insights
        json_executions = len(df[df['execution_type'] == 'json_profile'])
        degraded_entries = 0
        if json_executions > 0:
            json_df = df[df['execution_type'] == 'json_profile']
            degraded_entries = len(json_df[json_df['degradation_assignments'] != 'none'])
        
        performance_data = {
            'Performance Metrics': [
                'Total Processing Time',
                'Total Boxes Processed',
                'Average Speed',
                'Speed Standard Deviation',
                'Fastest Execution',
                'Slowest Execution',
                'Max Boxes (Single)',
                'Median Speed'
            ],
            'Values': [
                f"{total_time_hours:.2f} hours",
                f"{total_boxes:,} boxes",
                f"{avg_speed:.2f} boxes/sec",
                f"{speed_std:.2f} boxes/sec",
                f"{fastest_execution:.0f}ms",
                f"{slowest_execution:.0f}ms",
                f"{max_boxes_single} boxes",
                f"{median_speed:.2f} boxes/sec"
            ]
        }
        
        fig.add_trace(
            go.Table(
                header=dict(
                    values=['🔍 Performance Insights', '📊 Data'],
                    fill_color='#e74c3c',
                    font_color='white',
                    font_size=11,
                    align='center'
                ),
                cells=dict(
                    values=list(performance_data.values()),
                    fill_color=['#f8f9fa', '#ffffff'] * 4,
                    font_size=10,
                    align=['left', 'right']
                )
            ),
            row=row, col=col
        )
    
    def create_empty_dashboard(self, filter_mode):
        """Create dashboard when no data is available"""
        fig = go.Figure()
        fig.add_annotation(
            text=f"No MacroMaster data available for {filter_mode} period<br>Start using MacroMaster to generate analytics!",
            xref="paper", yref="paper",
            x=0.5, y=0.5, 
            showarrow=False,
            font=dict(size=18)
        )
        fig.update_layout(
            title="🎮 MacroMaster Analytics - No Data",
            template="plotly_white",
            height=800
        )
        output_file = f"macromaster_optimized_{filter_mode}_empty.html"
        fig.write_html(output_file, auto_open=False)
        webbrowser.open(f"file://{os.path.abspath(output_file)}")
        print(f"Empty MacroMaster dashboard created: macromaster_optimized_{filter_mode}_empty.html")
    
    def save_optimized_metrics(self, df, filter_mode):
        """Save optimized metrics"""
        try:
            total_executions = len(df)
            total_boxes = int(df['total_boxes'].sum()) if not df.empty else 0
            macro_count = len(df[df['execution_type'] == 'macro'])
            json_count = len(df[df['execution_type'] == 'json_profile'])
            avg_execution_time = df['execution_time_ms'].mean() if not df.empty else 0
            efficiency = df['boxes_per_second'].mean() if not df.empty else 0
            
            # Session duration
            session_duration_hours = 0
            if not df.empty:
                session_duration_hours = (df['timestamp'].max() - df['timestamp'].min()).total_seconds() / 3600
            
            # Button analysis
            button_stats = {}
            if 'button_key' in df.columns and not df.empty:
                button_stats = df.groupby('button_key')['total_boxes'].sum().to_dict()
            
            # Degradation analysis - include both macro and json_profile executions
            degradation_df = df[
                (df['execution_type'].isin(['json_profile', 'macro'])) &
                (df['degradation_assignments'].notna()) &
                (df['degradation_assignments'] != '') &
                (df['degradation_assignments'] != 'clear')
            ]
            degradation_stats = degradation_df['degradation_assignments'].value_counts().to_dict() if not degradation_df.empty else {}

            # Quality score based on degradation rate
            quality_score = 100
            if len(df) > 0:
                # Count non-clear degradations vs total executions
                degraded_count = len(degradation_df)
                degradation_rate = (degraded_count / len(df)) * 100
                quality_score = max(0, 100 - degradation_rate)
            
            metrics = {
                "filter_mode": filter_mode,
                "dashboard_type": "optimized_9_chart",
                "total_executions": total_executions,
                "macro_executions": macro_count,
                "json_executions": json_count,
                "total_boxes": total_boxes,
                "avg_execution_time_ms": round(avg_execution_time, 1) if pd.notna(avg_execution_time) else 0,
                "efficiency_boxes_per_second": round(efficiency, 2) if pd.notna(efficiency) else 0,
                "session_duration_hours": round(session_duration_hours, 1),
                "boxes_per_hour": round(total_boxes/session_duration_hours, 1) if session_duration_hours > 0 else 0,
                "quality_score": round(quality_score, 1),
                "button_performance": button_stats,
                "degradation_breakdown": degradation_stats,
                "generated_at": datetime.now().isoformat()
            }
            
            with open(f"macromaster_optimized_metrics_{filter_mode}.json", 'w') as f:
                json.dump(metrics, f, indent=2)
                
            print(f"MacroMaster optimized metrics saved: macromaster_optimized_metrics_{filter_mode}.json")
                
        except Exception as e:
            print(f"Error saving MacroMaster optimized metrics: {e}")

def main():
    parser = argparse.ArgumentParser(description='MacroMaster Optimized Analytics Dashboard')
    parser.add_argument('csv_path', help='Path to the MacroMaster CSV data file')
    parser.add_argument('--filter', choices=['all', 'today', 'session', 'week'], 
                       default='all', help='Data filter mode')
    parser.add_argument('--days', type=int, help='Filter to last N days')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.csv_path):
        print(f"Error: MacroMaster CSV file not found: {args.csv_path}")
        return
    
    # Create MacroMaster optimized analytics dashboard
    analytics = MacroMasterOptimizedAnalytics(args.csv_path)
    analytics.create_optimized_dashboard(args.filter)

if __name__ == "__main__":
    main()